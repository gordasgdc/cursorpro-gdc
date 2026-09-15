import AppKit

/// Draws the halo, the spotlight mask, and freehand draw strokes for the
/// screen this view's window covers. Pure Core Graphics — no SwiftUI —
/// since this repaints at high frequency and needs precise, cheap control
/// over exactly what gets composited.
final class OverlayView: NSView {
    private let state = AppState.shared
    private var refreshTimer: Timer?

    /// Ultima regiune ocupata de halo, in coordonate locale. Invalidarea
    /// trebuie sa acopere ATAT pozitia veche (ca sa stearga urma), CAT si pe
    /// cea noua — altfel raman dare pe ecran la miscarea cursorului.
    private var lastHaloRect: NSRect = .zero
    private var displayLink: CADisplayLink?

    /// [2026-09-12] Cadrul ANTERIOR a desenat un element care acopera tot
    /// ecranul (masca de spotlight, desene, efecte)? Fara asta, trecerea de la
    /// "acopera tot" la "doar halo" invalideaza doar dreptunghiul mic din jurul
    /// cursorului: `ctx.clear(dirtyRect)` sterge acel dreptunghi din masca
    /// ramasa pe ecran, iar dedesubt apare desktopul — exact patratelele care
    /// se vedeau la miscarea mouse-ului, ca si cum ai sterge cu buretele.
    /// Un cadru complet in plus dupa ultimul cadru "plin" sterge masca intreaga.
    private var lastFrameWasFullScreen = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear

        // [2026-09-11] Inainte: un Timer fix la 1/60s care punea
        // `needsDisplay = true` pe TOT view-ul — adica repictarea intregului
        // ecran (pe un 4K, ~8.8 milioane de pixeli) de 60 de ori pe secunda,
        // doar ca sa mute un inel de cativa zeci de pixeli. Cu halo/lupa la
        // dimensiunile mari cerute acum, costul asta devine vizibil.
        //
        // Acum: CADisplayLink, sincronizat cu rata REALA a ecranului — 120Hz
        // pe ProMotion (unde Timer-ul fix pierdea jumatate din cadre si se
        // vedea ca micro-sacadare), 60Hz pe restul, si se opreste singur cand
        // ecranul nu deseneaza. Disponibil nativ pe NSView de la macOS 14,
        // care e deja minimul aplicatiei (LSMinimumSystemVersion 14.0).
        let link = displayLink(target: self, selector: #selector(onDisplayTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit {
        refreshTimer?.invalidate()
        displayLink?.invalidate()
    }

    /// Invalideaza DOAR ce s-a schimbat.
    ///
    /// Cand singurul element viu e halo-ul (cazul normal de utilizare zilnica,
    /// cu aplicatia pornita permanent), se repicteaza o zona de cateva sute de
    /// pixeli in loc de tot ecranul. Cand e activ un mod care chiar acopera
    /// toata suprafata (spotlight-ul intuneca tot ecranul, desenul si efectele
    /// de click pot fi oriunde), se cade inapoi pe invalidarea totala — corect
    /// inainte de rapid.
    @objc private func onDisplayTick() {
        // Starea REALA a tastelor modificatoare, citita sincron — un eveniment
        // pierdut nu mai poate lasa un mod blocat pornit (vezi
        // InputMonitor.reconcileModifierState).
        AppDelegate.shared?.reconcileInputState()

        // `lastFrameWasFullScreen`: chiar daca ACUM nu mai e nimic pe tot
        // ecranul, cadrul precedent a lasat ceva desenat acolo — trebuie sters
        // integral, nu partial.
        guard !needsFullRedraw && !lastFrameWasFullScreen else {
            lastHaloRect = .zero
            needsDisplay = true
            return
        }

        let cursor = localPoint(fromGlobal: state.mouseLocation)
        let extent = state.maxHaloExtent
        let haloRect = NSRect(x: cursor.x - extent, y: cursor.y - extent,
                              width: extent * 2, height: extent * 2)

        // Uniunea vechi+nou: pozitia veche trebuie stearsa, cea noua desenata.
        let dirty = lastHaloRect.isEmpty ? haloRect : haloRect.union(lastHaloRect)
        lastHaloRect = haloRect

        // Peste un anumit prag, invalidarea partiala nu mai aduce nimic —
        // compunerea a doua regiuni mari costa cat una singura pe tot ecranul.
        if dirty.width * dirty.height > bounds.width * bounds.height * 0.5 {
            needsDisplay = true
        } else {
            setNeedsDisplay(dirty.insetBy(dx: -2, dy: -2))
        }
    }

    /// Modurile care pot desena oriunde pe ecran, deci cer repictare totala.
    private var needsFullRedraw: Bool {
        // Conditiile sunt copiate EXACT din garzile fiecarei functii de
        // desenare (drawStrokes / drawClickEffects / drawKeystrokeBadge) —
        // verificate direct in cod, nu presupuse. Daca vreuna dintre ele s-ar
        // desincroniza, un element ar putea fi desenat in afara regiunii
        // invalidate si ar lasa urme pe ecran.
        if state.isSpotlightActive || state.isDrawActive { return true }
        if !state.drawItems.isEmpty { return true }
        if state.currentFreehand.count > 1 { return true }
        if state.shapeStart != nil && state.shapeCurrent != nil { return true }
        if !state.clickEffects.isEmpty { return true }
        // Badge-ul de taste se deseneaza langa cursor, dar are propria lui
        // geometrie (pila de text) pe care regiunea halo-ului n-o acopera.
        if state.keystrokeOverlayEnabled, state.lastKeystroke != nil {
            let elapsed = ProcessInfo.processInfo.systemUptime - state.lastKeystrokeTime
            if elapsed >= 0, elapsed <= state.keystrokeDisplayDuration { return true }
        }
        return false
    }

    /// This screen's frame in *global* coordinates (bottom-left origin,
    /// y-up) — used to convert AppState's global mouse point into a point
    /// local to this view.
    private var screenOrigin: NSPoint {
        window?.frame.origin ?? .zero
    }

    private func localPoint(fromGlobal global: NSPoint) -> NSPoint {
        NSPoint(x: global.x - screenOrigin.x, y: global.y - screenOrigin.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // [2026-09-11] `dirtyRect`, nu `bounds`: cu invalidarea partiala de
        // mai sus, stergerea trebuie sa acopere exact regiunea redesenata.
        // [2026-09-12] ...DAR doar cat timp pe ecran nu exista (si n-a existat
        // in cadrul precedent) un element care acopera tot. In acel caz
        // stergerea partiala taie o gaura in masca deja desenata. Aici
        // `bounds` e obligatoriu, nu o optimizare ratata.
        let fullScreenFrame = needsFullRedraw || lastFrameWasFullScreen
        ctx.clear(fullScreenFrame ? bounds : dirtyRect)
        lastFrameWasFullScreen = needsFullRedraw

        let cursor = localPoint(fromGlobal: state.mouseLocation)

        if state.isSpotlightActive {
            drawSpotlight(ctx: ctx, at: cursor)
        }

        drawStrokes(ctx: ctx)
        drawClickEffects(ctx: ctx)

        if state.haloEnabled && LicenseManager.shared.isUnlocked {
            drawHalo(ctx: ctx, at: cursor)
        }

        drawKeystrokeBadge(ctx: ctx, at: cursor)
    }

    // MARK: - Halo

    private func drawHalo(ctx: CGContext, at point: NSPoint) {
        let d = state.haloDiameter
        let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
        let color = state.haloColor.cgColor

        switch state.haloStyle {
        case .ring:
            ctx.setStrokeColor(color)
            ctx.setLineWidth(state.haloLineWidth)
            ctx.strokeEllipse(in: rect)

        case .filled:
            ctx.setFillColor(color.copy(alpha: 0.55) ?? color)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(color)
            ctx.setLineWidth(state.haloLineWidth)
            ctx.strokeEllipse(in: rect)

        case .crosshair:
            ctx.setStrokeColor(color)
            ctx.setLineWidth(state.haloLineWidth)
            ctx.strokeEllipse(in: rect)
            let tick = d * 0.4
            ctx.move(to: CGPoint(x: point.x - d / 2 - tick, y: point.y))
            ctx.addLine(to: CGPoint(x: point.x - d / 2, y: point.y))
            ctx.move(to: CGPoint(x: point.x + d / 2, y: point.y))
            ctx.addLine(to: CGPoint(x: point.x + d / 2 + tick, y: point.y))
            ctx.move(to: CGPoint(x: point.x, y: point.y - d / 2 - tick))
            ctx.addLine(to: CGPoint(x: point.x, y: point.y - d / 2))
            ctx.move(to: CGPoint(x: point.x, y: point.y + d / 2))
            ctx.addLine(to: CGPoint(x: point.x, y: point.y + d / 2 + tick))
            ctx.strokePath()
        }
    }

    // MARK: - Spotlight

    private func drawSpotlight(ctx: CGContext, at point: NSPoint) {
        ctx.saveGState()
        // Even-odd fill of (full bounds path) + (circle path) leaves a
        // circular hole in an otherwise solid mask.
        let path = CGMutablePath()
        path.addRect(bounds)
        let r = state.spotlightRadius
        path.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))

        ctx.addPath(path)
        ctx.setFillColor(NSColor.black.withAlphaComponent(state.spotlightDimOpacity).cgColor)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    // MARK: - Draw

    private func drawStrokes(ctx: CGContext) {
        let hasCommitted = !state.drawItems.isEmpty
        let hasFreehandInProgress = state.currentFreehand.count > 1
        let hasShapeInProgress = state.shapeStart != nil && state.shapeCurrent != nil
        guard hasCommitted || hasFreehandInProgress || hasShapeInProgress else { return }

        ctx.setStrokeColor(state.drawColor.cgColor)
        ctx.setLineWidth(state.drawLineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        for item in state.drawItems {
            drawItem(ctx: ctx, item: item)
        }
        if hasFreehandInProgress {
            strokePath(ctx: ctx, points: state.currentFreehand)
        }
        if hasShapeInProgress, let start = state.shapeStart, let current = state.shapeCurrent {
            drawShapePreview(ctx: ctx, from: start, to: current)
        }
    }

    private func drawItem(ctx: CGContext, item: AppState.DrawItem) {
        switch item {
        case .freehand(let points):
            strokePath(ctx: ctx, points: points)
        case .arrow(let start, let end):
            drawArrow(ctx: ctx, from: localPoint(fromGlobal: start), to: localPoint(fromGlobal: end))
        case .ellipse(let start, let end):
            drawEllipse(ctx: ctx, from: localPoint(fromGlobal: start), to: localPoint(fromGlobal: end))
        case .rectangle(let start, let end):
            drawRectangle(ctx: ctx, from: localPoint(fromGlobal: start), to: localPoint(fromGlobal: end))
        }
    }

    private func drawShapePreview(ctx: CGContext, from start: NSPoint, to end: NSPoint) {
        let a = localPoint(fromGlobal: start)
        let b = localPoint(fromGlobal: end)
        switch state.drawTool {
        case .freehand: break
        case .arrow: drawArrow(ctx: ctx, from: a, to: b)
        case .ellipse: drawEllipse(ctx: ctx, from: a, to: b)
        case .rectangle: drawRectangle(ctx: ctx, from: a, to: b)
        }
    }

    private func strokePath(ctx: CGContext, points: [NSPoint]) {
        guard let first = points.first else { return }
        ctx.beginPath()
        ctx.move(to: localPoint(fromGlobal: first))
        for p in points.dropFirst() {
            ctx.addLine(to: localPoint(fromGlobal: p))
        }
        ctx.strokePath()
    }

    /// A straight shaft plus a filled triangular head, pointing from
    /// `start` to `end` — for calling out something on screen.
    private func drawArrow(ctx: CGContext, from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return }
        let angle = atan2(dy, dx)

        let headLength = min(max(state.drawLineWidth * 4, 14), 34)
        let headAngle = CGFloat.pi / 7

        // Pull the shaft back so it ends at the base of the arrowhead,
        // not underneath it.
        let shaftEnd = CGPoint(x: end.x - cos(angle) * headLength * 0.6,
                                y: end.y - sin(angle) * headLength * 0.6)

        ctx.beginPath()
        ctx.move(to: start)
        ctx.addLine(to: shaftEnd)
        ctx.strokePath()

        let p1 = CGPoint(x: end.x - headLength * cos(angle - headAngle),
                          y: end.y - headLength * sin(angle - headAngle))
        let p2 = CGPoint(x: end.x - headLength * cos(angle + headAngle),
                          y: end.y - headLength * sin(angle + headAngle))

        ctx.beginPath()
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.setFillColor(state.drawColor.cgColor)
        ctx.fillPath()
    }

    /// An "encircle" oval spanning the two corner points.
    private func drawEllipse(ctx: CGContext, from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
        ctx.strokeEllipse(in: rect)
    }

    /// A rectangular selection frame spanning the two corner points.
    private func drawRectangle(ctx: CGContext, from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
        ctx.stroke(rect)
    }

    // MARK: - Click Effects (ripples)

    private func pruneClickEffects() {
        let now = ProcessInfo.processInfo.systemUptime
        state.clickEffects.removeAll { now - $0.time > state.clickEffectDuration }
    }

    /// Expanding, fading ring at the click point. `.screenFound` (the
    /// multi-display ping) reuses the exact same mechanism with a
    /// bigger/slower ring — see AppState.ClickKind.
    private func drawClickEffects(ctx: CGContext) {
        pruneClickEffects()
        guard LicenseManager.shared.isUnlocked, !state.clickEffects.isEmpty else { return }

        let now = ProcessInfo.processInfo.systemUptime
        for effect in state.clickEffects {
            let elapsed = now - effect.time
            guard elapsed >= 0 else { continue }
            let progress = min(1, CGFloat(elapsed / state.clickEffectDuration))
            let point = localPoint(fromGlobal: effect.point)
            let isPing = effect.kind == .screenFound
            let startRadius: CGFloat = isPing ? 14 : 6
            let endRadius: CGFloat = isPing ? 70 : 36
            let radius = startRadius + (endRadius - startRadius) * progress
            let alpha = 1 - progress

            ctx.setStrokeColor(state.color(for: effect.kind).withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(isPing ? 3 : 2.5)
            ctx.strokeEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    // MARK: - Keystroke Overlay

    /// A small fading pill with the last shortcut pressed (e.g. "⌘C"),
    /// offset up-right from the cursor. Text drawing here relies on
    /// `NSGraphicsContext.current` already being this view's own context
    /// (true for the whole duration of `draw(_:)`), so no flip handling
    /// is needed — Cocoa's string-drawing APIs already account for it.
    private func drawKeystrokeBadge(ctx: CGContext, at cursor: CGPoint) {
        guard state.keystrokeOverlayEnabled, LicenseManager.shared.isUnlocked,
              let combo = state.lastKeystroke else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - state.lastKeystrokeTime
        guard elapsed >= 0, elapsed <= state.keystrokeDisplayDuration else { return }
        let progress = CGFloat(elapsed / state.keystrokeDisplayDuration)
        // Fully readable for the first 70% of the duration, then fade out.
        // The user's own opacity preference multiplies this, rather than
        // replacing it — a badge set to 30% opacity still fades to 0,
        // it just never gets brighter than 30% along the way.
        let fadeAlpha = progress < 0.7 ? 1 : max(0, 1 - (progress - 0.7) / 0.3)
        let alpha = fadeAlpha * state.keystrokeOpacity
        let scale = state.keystrokeScale

        let text = combo.label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15 * scale, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha)
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padding: CGFloat = 10 * scale
        let badgeSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding)

        let origin: CGPoint
        switch state.keystrokePosition {
        case .nearCursor:
            origin = CGPoint(x: cursor.x + 22, y: cursor.y + 22)
        case .bottomCenter:
            // Centrat orizontal, deasupra marginii de jos. Marginea creste cu
            // scara: la 800% un decalaj fix de 40 px ar lipi un badge urias de
            // marginea ecranului.
            let bottomMargin = 40 + 12 * (scale - 1)
            origin = CGPoint(x: (bounds.width - badgeSize.width) / 2,
                             y: bounds.minY + bottomMargin)
        }

        // `integral`: pe pozitia fixa, o coordonata fractionara face textul
        // usor neclar la fiecare cadru. Langa cursor nu se observa, fiindca
        // badge-ul oricum se misca.
        let badgeRect = CGRect(origin: origin, size: badgeSize).integral

        ctx.setFillColor(NSColor.black.withAlphaComponent(state.keystrokeBackgroundOpacity * alpha).cgColor)
        ctx.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 8 * scale, cornerHeight: 8 * scale, transform: nil))
        ctx.fillPath()

        (text as NSString).draw(
            at: CGPoint(x: badgeRect.minX + padding, y: badgeRect.minY + padding / 2),
            withAttributes: attrs
        )
    }
}
