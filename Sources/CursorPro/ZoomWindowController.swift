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
    /// Our own app's windows (the full-screen Halo/Spotlight/Draw overlay
    /// + this very loupe window) — excluded from every capture so we
    /// never magnify our own decorations by accident.
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
            reposition()
            recenterStreamIfNeeded()
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

            w.contentView = container
            self.window = w
            self.imageView = iv
        }
        window?.orderFrontRegardless()
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

        Task { [weak self] in
            do {
                try await newStream.startCapture()
                DebugLog.log("beginStream: SUCCESS, streaming \(Int(rectGlobal.width))x\(Int(rectGlobal.height))pt region")
            } catch {
                DebugLog.log("beginStream: startCapture failed: \(error)")
                await MainActor.run { self?.stream = nil }
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
                let myPID = ProcessInfo.processInfo.processIdentifier
                self.ownWindowsToExclude = content.windows.filter { $0.owningApplication?.processID == myPID }
                DebugLog.log("refreshDisplays: got \(content.displays.count) displays, excluding \(self.ownWindowsToExclude.count) of our own windows")
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
        guard let cgImage = ciContext.createCGImage(cropped, from: cropRect) else {
            if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): createCGImage FAILED") }
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: radius * 2, height: radius * 2))
        if n <= 3 { DebugLog.log("didOutputSampleBuffer #\(n): setting image, size=\(nsImage.size)") }
        DispatchQueue.main.async { [weak self] in
            self?.imageView?.image = nsImage
        }
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
