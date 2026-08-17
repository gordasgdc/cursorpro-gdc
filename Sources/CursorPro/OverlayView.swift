import AppKit

/// Draws the halo, the spotlight mask, and freehand draw strokes for the
/// screen this view's window covers. Pure Core Graphics — no SwiftUI —
/// since this repaints at high frequency and needs precise, cheap control
/// over exactly what gets composited.
final class OverlayView: NSView {
    private let state = AppState.shared
    private var refreshTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear

        // Simple, robust redraw loop: repaint at ~60fps whenever any mode
        // is active or the halo is on, so cursor tracking and drawing feel
        // live. Idle (halo off, no mode held) costs nothing extra since we
        // still only redraw on a timer tick, not per pixel.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit { refreshTimer?.invalidate() }

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
        ctx.clear(bounds)

        let cursor = localPoint(fromGlobal: state.mouseLocation)

        if state.isSpotlightActive {
            drawSpotlight(ctx: ctx, at: cursor)
        }

        drawStrokes(ctx: ctx)

        if state.haloEnabled && LicenseManager.shared.isUnlocked {
            drawHalo(ctx: ctx, at: cursor)
        }
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
}
