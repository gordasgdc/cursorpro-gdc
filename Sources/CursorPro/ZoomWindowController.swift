import AppKit
import ScreenCaptureKit
import CoreImage

/// While the Zoom key is held, shows a small floating circular window
/// centered on the cursor containing a magnified, LIVE view of the screen
/// region right around it.
///
/// History: every earlier version of this repeatedly took one-shot
/// screenshots (`SCScreenshotManager.captureImage`) on a timer, either
/// every tick (heavy enough to stall the system) or once per activation
/// (cheap, but the picture goes stale/frozen the moment the mouse moves
/// even slightly, and looking at it side by side with a reference
/// implementation — a live video feed transformed on screen — the
/// "which area is this even showing" confusion made sense: a frozen
/// snapshot re-centered in discrete jumps doesn't read as "a live loupe
/// following your cursor" the way continuous video does.
///
/// This version uses `SCStream`, ScreenCaptureKit's actual continuous
/// capture API (as opposed to the one-shot screenshot API), which is
/// what it's built for: it keeps delivering fresh frames of a region on
/// its own, and reconfiguring which region (`updateContentFilter`) is a
/// cheap, fast operation instead of a fresh multi-step capture. The
/// loupe now shows genuinely live content the entire time the key is
/// held, and only asks ScreenCaptureKit to re-center the streamed region
/// when the cursor has drifted near the edge of what's currently
/// streamed.
@available(macOS 14.0, *)
final class ZoomWindowController: NSObject {
    private let state = AppState.shared
    private var window: NSWindow?
    private var imageView: NSImageView?
    private var colorLabel: NSTextField?
    /// Refreshed on the main thread (showWindow/reposition) whenever the
    /// loupe window is created or moved — read from the background
    /// frame-output thread for the crisp-scaling render path, same
    /// deliberate low-risk trade already used for radius/scale below.
    private var cachedBackingScale: CGFloat = 2
    private var pollTimer: Timer?
    private var wasActive = false

    private var stream: SCStream?
    private var currentDisplay: SCDisplay?
    /// The region (global points) the stream is currently configured to
    /// capture. Frames keep arriving live for this region until we
    /// explicitly re-center it.
    private var streamedRectGlobal: CGRect = .zero
    private var scaleX: CGFloat = 1
    private var scaleY: CGFloat = 1
    private var isReconfiguring = false
    private var frameCount = 0

    private var cachedDisplays: [SCDisplay] = []
    /// ONLY the full-screen Halo/Spotlight/Draw overlay windows + this
    /// very loupe window — excluded from every capture so we never
    /// magnify our own transparent decorations by accident.
    ///
    /// BUG REAL (raportat de Cristi, 2026-08-31: zoom-ul arata continut
    /// "de departe, din lateral" cand incerca sa faca zoom chiar pe
    /// fereastra de Preferinte a aplicatiei). Cauza reala, confirmata din
    /// `~/Desktop/cursorpro_debug.log`: matematica de urmarire a
    /// cursorului era mereu corecta (crop-ul era mereu centrat exact pe
    /// pozitia reala a cursorului) — problema era ca acest filtru excludea
    /// TOATE ferestrele detinute de procesul CursorPro, inclusiv fereastra
    /// normala de Preferinte (nu doar overlay-urile transparente). Cand
    /// userul tinea zoom-ul chiar deasupra propriei ferestre de Preferinte
    /// (exact scenariul de test), ScreenCaptureKit o ascundea din captura —
    /// lupa arata deci, corect din punct de vedere geometric, CE ERA IN
    /// SPATELE ei pe ecran (o alta fereastra, oriunde s-ar fi aflat), nu
    /// fereastra pe care userul chiar voia sa o vada marita. Fix: excludem
    /// acum STRICT overlay-urile transparente (Halo/Spotlight/Draw) + lupa
    /// insasi, identificate dupa `windowNumber` (via `AppDelegate.shared`),
    /// nu mai excludem dupa PID (care prindea orbeste orice fereastra
    /// reala a aplicatiei, prezenta sau viitoare).
    private var ownWindowsToExclude: [SCWindow] = []
    private var isRefreshingDisplays = false

    /// How much extra margin (in points, beyond the visible radius) the
    /// streamed region covers, so small mouse movements don't force a
    /// re-center.
    private let streamMarginMultiplier: CGFloat = 2.5

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let frameQueue = DispatchQueue(label: "com.gordasgdc.cursorpro.zoomframes", qos: .userInteractive)

    override init() {
        super.init()
        // Just drives repositioning/margin checks; actual frames arrive
        // continuously and independently from the stream itself.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    deinit {
        pollTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensChanged() {
        cachedDisplays = []
    }

    private func tick() {
        if state.isZoomActive {
            if !wasActive {
                DebugLog.log("tick: activating zoom")
                showWindow()
                startStreamIfNeeded()
            }
            wasActive = true
            colorLabel?.isHidden = !state.magnifierColorPickerEnabled
            updateLockVisual()
            if !state.isMagnifierLocked {
                reposition()
                recenterStreamIfNeeded()
            }
        } else if wasActive {
            DebugLog.log("tick: deactivating zoom")
            wasActive = false
            window?.orderOut(nil)
            stopStream()
        }
    }

    private func showWindow() {
        if window == nil {
            let d = AppState.zoomWindowDiameter
            let size = NSSize(width: d, height: d)
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.level = .screenSaver
            w.ignoresMouseEvents = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.isReleasedWhenClosed = false

            let container = NSView(frame: NSRect(origin: .zero, size: size))
            container.wantsLayer = true
            container.layer?.cornerRadius = size.width / 2
            container.layer?.masksToBounds = true
            container.layer?.borderWidth = 2
            container.layer?.borderColor = NSColor.white.withAlphaComponent(0.85).cgColor

            let iv = NSImageView(frame: container.bounds)
            iv.imageScaling = .scaleAxesIndependently
            iv.autoresizingMask = [.width, .height]
            container.addSubview(iv)

            let reticle = ZoomReticleView(frame: container.bounds)
            reticle.autoresizingMask = [.width, .height]
            container.addSubview(reticle)

            // Pixel color readout (HEX/RGB/Display P3) — sits low inside
            // the circular mask so it never gets clipped by the corner
            // radius; hidden unless the user turns the feature on.
            let label = NSTextField(labelWithString: "")
            label.alignment = .center
            label.font = .systemFont(ofSize: 10, weight: .semibold)
            label.textColor = .white
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byClipping
            label.frame = NSRect(x: 20, y: 14, width: size.width - 40, height: 28)
            label.autoresizingMask = [.width]
            let textShadow = NSShadow()
            textShadow.shadowColor = .black
            textShadow.shadowBlurRadius = 3
            textShadow.shadowOffset = .zero
            label.shadow = textShadow
            label.isHidden = !state.magnifierColorPickerEnabled
            container.addSubview(label)
            self.colorLabel = label

            w.contentView = container
            self.window = w
            self.imageView = iv
        }
        window?.orderFrontRegardless()
        cachedBackingScale = window?.backingScaleFactor ?? cachedBackingScale
    }

    private func reposition() {
        let cursor = state.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }
        guard let w = window else { return }
        let size = w.frame.size
        var origin = NSPoint(x: cursor.x - size.width / 2, y: cursor.y - size.height / 2)
        origin.x = max(screen.frame.minX, min(origin.x, screen.frame.maxX - size.width))
        origin.y = max(screen.frame.minY, min(origin.y, screen.frame.maxY - size.height))
        w.setFrameOrigin(origin)
        // A cross-screen move can land on a display with a different
        // backing scale (e.g. Retina laptop -> external non-Retina).
        cachedBackingScale = w.backingScaleFactor
    }

    /// Orange ring while the frame is locked (vs. the normal white
    /// border) — the only visual cue that the loupe has stopped
    /// following the cursor, since its position genuinely doesn't move.
    private func updateLockVisual() {
        guard let container = window?.contentView else { return }
        let color: NSColor = state.isMagnifierLocked ? .systemOrange : NSColor.white.withAlphaComponent(0.85)
        container.layer?.borderColor = color.cgColor
    }

    // MARK: - Stream lifecycle

    private func startStreamIfNeeded() {
        guard stream == nil else { return }
        let cursor = state.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }
        guard let display = cachedDisplays.first(where: { self.cgDisplayMatches($0, screen: screen) }) else {
            refreshDisplaysIfNeeded()
            return
        }
        beginStream(on: display, screen: screen, centeredOn: cursor)
    }

    private func beginStream(on display: SCDisplay, screen: NSScreen, centeredOn cursor: NSPoint) {
        frameCount = 0
        let radius = state.zoomRadius
        let captureRadius = radius * streamMarginMultiplier
        let screenFrame = screen.frame

        let sx = CGFloat(display.width) / screenFrame.width
        let sy = CGFloat(display.height) / screenFrame.height

        let rectGlobal = CGRect(x: cursor.x - captureRadius, y: cursor.y - captureRadius, width: captureRadius * 2, height: captureRadius * 2)
        let localRectPixels = Self.pixelRect(forGlobal: rectGlobal, screenFrame: screenFrame, scaleX: sx, scaleY: sy)

        let filter = SCContentFilter(display: display, excludingWindows: ownWindowsToExclude)
        let config = SCStreamConfiguration()
        config.sourceRect = localRectPixels
        config.width = max(2, Int(localRectPixels.width))
        config.height = max(2, Int(localRectPixels.height))
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 20) // 20fps is smooth and cheap for a small region
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameQueue)
        } catch {
            DebugLog.log("beginStream: addStreamOutput failed: \(error)")
            return
        }

        currentDisplay = display
        streamedRectGlobal = rectGlobal
        scaleX = sx
        scaleY = sy
        stream = newStream

        // @MainActor, same convention as refreshDisplaysIfNeeded() below —
        // avoids a nested `await MainActor.run { self?.x = ... }` closure,
        // which the Swift 6 concurrency checker flags (capturing a weak
        // `self` a second time, across a second closure boundary) even
        // though it was already safe here.
        Task { @MainActor [weak self] in
            do {
                try await newStream.startCapture()
                DebugLog.log("beginStream: SUCCESS, streaming \(Int(rectGlobal.width))x\(Int(rectGlobal.height))pt region")
            } catch {
                DebugLog.log("beginStream: startCapture failed: \(error)")
                self?.stream = nil
            }
        }
    }

    private func stopStream() {
        guard let s = stream else { return }
        stream = nil
        Task {
            try? await s.stopCapture()
        }
    }

    /// If the cursor has drifted near the edge of the currently-streamed
    /// region, reconfigure the SAME stream to re-center on the cursor's
    /// new spot — cheap relative to starting a whole new stream.
    private func recenterStreamIfNeeded() {
        guard let s = stream, !isReconfiguring, let display = currentDisplay else { return }
        let cursor = state.mouseLocation
        let radius = state.zoomRadius
        let margin = radius * streamMarginMultiplier

        let center = NSPoint(x: streamedRectGlobal.midX, y: streamedRectGlobal.midY)
        let drift = hypot(cursor.x - center.x, cursor.y - center.y)
        guard drift > margin * 0.8 else { return }

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }
        let screenFrame = screen.frame
        let captureRadius = radius * streamMarginMultiplier
        let rectGlobal = CGRect(x: cursor.x - captureRadius, y: cursor.y - captureRadius, width: captureRadius * 2, height: captureRadius * 2)
        let localRectPixels = Self.pixelRect(forGlobal: rectGlobal, screenFrame: screenFrame, scaleX: scaleX, scaleY: scaleY)

        let filter = SCContentFilter(display: display, excludingWindows: ownWindowsToExclude)
        let config = SCStreamConfiguration()
        config.sourceRect = localRectPixels
        config.width = max(2, Int(localRectPixels.width))
        config.height = max(2, Int(localRectPixels.height))
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 20)
        config.queueDepth = 3
        config.pixelFormat = kCVPixelFormatType_32BGRA

        isReconfiguring = true
        streamedRectGlobal = rectGlobal
        Task { [weak self] in
            defer { self?.isReconfiguring = false }
            do {
                try await s.updateContentFilter(filter)
                try await s.updateConfiguration(config)
            } catch {
                DebugLog.log("recenterStream: update failed: \(error)")
            }
        }
    }

    private func refreshDisplaysIfNeeded() {
        guard !isRefreshingDisplays else { return }
        isRefreshingDisplays = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isRefreshingDisplays = false }
            do {
                let content = try await SCShareableContent.current
                self.cachedDisplays = content.displays
                var excludeIDs = Set(AppDelegate.shared?.overlayWindowIDs ?? [])
                if let loupeWindowNumber = self.window?.windowNumber {
                    excludeIDs.insert(CGWindowID(loupeWindowNumber))
                }
                self.ownWindowsToExclude = content.windows.filter { excludeIDs.contains($0.windowID) }
                DebugLog.log("refreshDisplays: got \(content.displays.count) displays, excluding \(self.ownWindowsToExclude.count) overlay/loupe windows (was excluding ALL own-process windows before this fix)")
            } catch {
                DebugLog.log("refreshDisplays: FAILED: \(error)")
            }
        }
    }

    private func cgDisplayMatches(_ display: SCDisplay, screen: NSScreen) -> Bool {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
        return display.displayID == CGDirectDisplayID(truncating: num)
    }

    /// Converts a global-points rect to the display's pixel-space rect
    /// SCStreamConfiguration.sourceRect expects: top-left origin, scaled
    /// by the ACTUAL SCDisplay pixel dimensions vs this screen's own
    /// point frame (not assumed from backingScaleFactor, which can be
    /// wrong on a non-natively-scaled external display).
    private static func pixelRect(forGlobal rectGlobal: CGRect, screenFrame: CGRect, scaleX: CGFloat, scaleY: CGFloat) -> CGRect {
        let localPoints = CGRect(
            x: rectGlobal.origin.x - screenFrame.origin.x,
            y: screenFrame.maxY - rectGlobal.maxY,
            width: rectGlobal.width,
            height: rectGlobal.height
        )
        return CGRect(
            x: localPoints.origin.x * scaleX,
            y: localPoints.origin.y * scaleY,
            width: localPoints.width * scaleX,
            height: localPoints.height * scaleY
        )
    }

    /// Reads the single pixel at the exact center of `image` — which, by
    /// construction (see `cropRect` above), is always the pixel right
    /// under the cursor — and updates the on-screen readout. Sampled in
    /// Display P3 (the color space modern Mac displays actually capture
    /// in) then converted to sRGB for the HEX/RGB numbers, so both are
    /// accurate instead of treating raw P3 bytes as if they were sRGB.
    private func samplePixelColor(from image: CIImage) {
        let sampleRect = CGRect(x: image.extent.midX - 0.5, y: image.extent.midY - 0.5, width: 1, height: 1)
        guard image.extent.contains(sampleRect) else { return }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(image, toBitmap: &pixel, rowBytes: 4, bounds: sampleRect,
                          format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.displayP3))

        let p3 = NSColor(displayP3Red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                          blue: CGFloat(pixel[2]) / 255, alpha: 1)
        let srgb = p3.usingColorSpace(.sRGB) ?? p3
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        let p3r = Int((p3.redComponent * 255).rounded())
        let p3g = Int((p3.greenComponent * 255).rounded())
        let p3b = Int((p3.blueComponent * 255).rounded())
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let text = "\(hex)\nRGB \(r),\(g),\(b) · P3 \(p3r),\(p3g),\(p3b)"

        DispatchQueue.main.async { [weak self] in
            self?.colorLabel?.stringValue = text
        }
    }
}

// MARK: - SCStreamOutput / SCStreamDelegate

@available(macOS 14.0, *)
extension ZoomWindowController: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        frameCount += 1
        let n = frameCount
        if n <= 3 || n % 60 == 0 {
            DebugLog.log("didOutputSampleBuffer #\(n): outputType=\(outputType.rawValue) valid=\(sampleBuffer.isValid) hasImageBuffer=\(CMSampleBufferGetImageBuffer(sampleBuffer) != nil)")
        }

        guard outputType == .screen, sampleBuffer.isValid,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // This callback fires on frameQueue (a background queue), not
        // main — and it fires often (20x/sec). Blocking on the main
        // thread here every single frame (as an earlier version did via
        // DispatchQueue.main.sync) added just enough main-thread
        // contention, 20x/sec, for macOS's own hang detector to kick in
        // and show its spinning-wait cursor — which is exactly the
        // "shield" pattern that kept showing up inside the loupe.
        // NSEvent.mouseLocation is documented safe to call from any
        // thread; radius/streamedRect/scale only change rarely (on
        // activation/re-center, from the main thread), so reading them
        // here unsynchronized is a deliberate, low-risk trade — worst
        // case is one visually-stale frame, never a crash or a stall.
        let cursor = NSEvent.mouseLocation
        let radius = state.zoomRadius
        let streamedRect = streamedRectGlobal
        let sx = scaleX
        let sy = scaleY

        let fullCI = CIImage(cvPixelBuffer: pixelBuffer)

        // CIImage (like AppKit screen points) uses a BOTTOM-LEFT origin —
        // unlike CGImage, no vertical flip is needed here: position is
        // simply "how far cursor is from the streamed region's own
        // bottom-left corner," in points, then scaled to pixels.
        let localXPoints = (cursor.x - radius) - streamedRect.origin.x
        let localYPoints = (cursor.y - radius) - streamedRect.origin.y

        // BUG REAL (raportat de Cristi, 2026-08-31: "fac zoom si imi apare
        // dintr-o zona complet diferita, din lateral, de departe" — mai ales
        // la miscari rapide/mari ale mouse-ului, exact ce se intampla intr-o
        // prezentare). Cauza: cand mouse-ul sare o distanta mare intr-un
        // singur tick (33ms), fereastra lupei se muta INSTANT la pozitia noua
        // (`reposition()`, sincron), dar stream-ul ScreenCaptureKit inca
        // livreaza cadre din REGIUNEA VECHE pana se termina re-centrarea
        // asincrona (`recenterStreamIfNeeded`, poate dura 100-300ms). Codul
        // vechi calcula crop-ul geometric fata de regiunea veche si, daca
        // exista orice suprapunere nevida cu cadrul curent, il afisa oricum —
        // deci userul vedea, pentru o fractiune de secunda, continut real de
        // pe ecran, dar dintr-o zona complet neinrudita cu pozitia actuala a
        // cursorului. Fix: daca centrul regiunii transmise curent e prea
        // departe de cursorul REAL de acum, cadrul e cunoscut ca fiind stale
        // — se sare afisarea lui (pastram ultima imagine buna) in loc sa
        // aratam ceva clar gresit, pana cand re-centrarea aduce cadre noi,
        // corecte.
        let driftFromCenter = hypot(cursor.x - streamedRect.midX, cursor.y - streamedRect.midY)
        guard driftFromCenter <= radius * 2.5 else {
            if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): stream stale (drift=\(driftFromCenter)), skipping frame") }
            return
        }

        let cropRect = CGRect(
            x: localXPoints * sx,
            y: localYPoints * sy,
            width: radius * 2 * sx,
            height: radius * 2 * sy
        ).intersection(fullCI.extent)

        if n <= 3 {
            DebugLog.log("didOutputSampleBuffer #\(n): fullCI.extent=\(fullCI.extent) streamedRect=\(streamedRect) cursor=\(cursor) radius=\(radius) cropRect=\(cropRect)")
        }

        guard !cropRect.isEmpty else {
            if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): cropRect EMPTY, skipping") }
            return
        }
        let cropped = fullCI.cropped(to: cropRect)
        if state.magnifierColorPickerEnabled {
            samplePixelColor(from: cropped)
        }
        guard let cgImage = ciContext.createCGImage(cropped, from: cropRect) else {
            if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): createCGImage FAILED") }
            return
        }

        // Smooth (default): tag the image at its true point size and let
        // NSImageView's own upscaling to the 360pt loupe do the interpolation,
        // exactly as always. Crisp: pre-render ourselves at the loupe's
        // ACTUAL pixel size with .none interpolation, tagged at the FULL
        // 360pt size — NSImageView then draws it 1:1, so nothing softens
        // our nearest-neighbor pixels afterwards.
        let nsImage: NSImage
        if state.magnifierSmoothScaling {
            nsImage = NSImage(cgImage: cgImage, size: NSSize(width: radius * 2, height: radius * 2))
        } else {
            nsImage = Self.renderCrisp(cgImage: cgImage, diameterPoints: AppState.zoomWindowDiameter, scale: cachedBackingScale)
                ?? NSImage(cgImage: cgImage, size: NSSize(width: radius * 2, height: radius * 2))
        }
        if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): setting image, size=\(nsImage.size), smooth=\(state.magnifierSmoothScaling)") }
        DispatchQueue.main.async { [weak self] in
            self?.imageView?.image = nsImage
        }
    }

    /// Re-renders `cgImage` at the loupe's real pixel size with nearest-
    /// neighbor interpolation — used only in crisp/pixel-inspection mode.
    /// `static` + no captured state: safe to call from the background
    /// frame-output thread.
    private static func renderCrisp(cgImage: CGImage, diameterPoints: CGFloat, scale: CGFloat) -> NSImage? {
        let targetPixels = max(2, Int((diameterPoints * scale).rounded()))
        guard let ctx = CGContext(
            data: nil, width: targetPixels, height: targetPixels,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetPixels, height: targetPixels))
        guard let output = ctx.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: diameterPoints, height: diameterPoints))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DebugLog.log("stream: didStopWithError \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.stream = nil
        }
    }
}

/// A small, perfectly symmetric crosshair drawn at the exact center of the
/// zoom window — a black-outlined white cross with a gap in the middle, so
/// it stays readable over any content.
private final class ZoomReticleView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let armLength: CGFloat = 9
        let gap: CGFloat = 4

        func drawCross(lineWidth: CGFloat, color: NSColor) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: center.x - armLength, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x - gap, y: center.y))
            ctx.move(to: CGPoint(x: center.x + gap, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + armLength, y: center.y))
            ctx.move(to: CGPoint(x: center.x, y: center.y - armLength))
            ctx.addLine(to: CGPoint(x: center.x, y: center.y - gap))
            ctx.move(to: CGPoint(x: center.x, y: center.y + gap))
            ctx.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
            ctx.strokePath()
        }

        drawCross(lineWidth: 3.5, color: NSColor.black.withAlphaComponent(0.65))
        drawCross(lineWidth: 1.5, color: .white)
    }
}
