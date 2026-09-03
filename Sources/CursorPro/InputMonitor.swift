import AppKit

/// Watches mouse position, modifier-key state, and the reconfigurable
/// draw-tool shortcut keys system-wide (across every app, not just ours)
/// and updates `AppState` accordingly. Uses `NSEvent` global monitors.
/// Mouse-moved/dragged and flagsChanged don't need Accessibility, but
/// observing keyDown globally does — that's why CursorPro asks for
/// Accessibility up front; without it, mouse tracking/halo still work,
/// only the draw-tool keyboard shortcuts (and the newer keystroke
/// overlay / magnifier-lock shortcut below) won't fire.
final class InputMonitor {
    private let state = AppState.shared
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    /// Screen the cursor was last known to be on — used only to detect an
    /// actual crossing for the (opt-in) multi-display ping, never touched
    /// when that setting is off.
    private var lastScreen: NSScreen?

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .flagsChanged, .keyDown, .scrollWheel
        ]

        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            globalMonitors.append(g)
        }

        // Local monitor covers the (rare) case where one of our own
        // windows happens to be under the cursor / key window.
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            localMonitors.append(l)
        }

        // NSEvent global monitors don't fire for the very first flagsChanged
        // if a key was already held before start() ran, and mouseMoved only
        // fires on movement — so seed the initial position immediately.
        state.mouseLocation = NSEvent.mouseLocation
        lastScreen = NSScreen.screens.first(where: { $0.frame.contains(state.mouseLocation) })
    }

    func stop() {
        for m in globalMonitors { NSEvent.removeMonitor(m) }
        for m in localMonitors { NSEvent.removeMonitor(m) }
        globalMonitors.removeAll()
        localMonitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            updateMouseLocation()
            if state.isDrawActive {
                switch state.drawTool {
                case .freehand:
                    // Freehand draws on hover too, no click needed — a
                    // continuous marker trail while the draw key is held.
                    state.currentFreehand.append(state.mouseLocation)
                case .arrow, .ellipse, .rectangle:
                    // Shapes need a defined start/end, so they only track
                    // while the mouse button is actually down.
                    if state.shapeStart != nil {
                        state.shapeCurrent = state.mouseLocation
                    }
                }
                // Publish incrementally so the overlay redraws live while
                // drawing, not just once the stroke/shape ends.
                state.objectWillChange.send()
            }

        case .leftMouseDown:
            updateMouseLocation()
            if state.isDrawActive && state.drawTool != .freehand {
                state.shapeStart = state.mouseLocation
                state.shapeCurrent = state.mouseLocation
            }
            // Double-click delivers two separate leftMouseDown events
            // (clickCount 1, then clickCount 2) — showing a plain "left"
            // ring on the first and a distinct "double" ring on the
            // second is a faithful, low-latency rendering of what
            // actually happened, with no debounce delay on ordinary
            // single clicks.
            addClickEffect(at: state.mouseLocation, kind: event.clickCount >= 2 ? .double : .left)

        case .leftMouseUp:
            updateMouseLocation()
            if state.isDrawActive, state.drawTool != .freehand, let start = state.shapeStart {
                commitShape(from: start, to: state.mouseLocation)
            }
            state.shapeStart = nil
            state.shapeCurrent = nil

        case .rightMouseDown:
            state.mouseLocation = NSEvent.mouseLocation
            addClickEffect(at: state.mouseLocation, kind: .right)

        case .flagsChanged:
            let flags = event.modifierFlags
            // Trial expired, no license activated: real features stay
            // off no matter which key is held. The Preferences → License
            // page still works so the user can enter a code any time.
            let unlocked = LicenseManager.shared.isUnlocked

            let wasDrawing = state.isDrawActive
            let wasZooming = state.isZoomActive
            state.isZoomActive = unlocked && flags.contains(state.zoomKey.flag)
            state.isDrawActive = unlocked && flags.contains(state.drawKey.flag)
            state.isSpotlightActive = unlocked && flags.contains(state.spotlightKey.flag)

            if wasZooming && !state.isZoomActive {
                // Never leave the loupe frozen for next time without the
                // user explicitly asking again.
                state.isMagnifierLocked = false
            }

            if wasDrawing && !state.isDrawActive {
                // Draw key released: commit whatever was in progress.
                if state.currentFreehand.count > 1 {
                    state.drawItems.append(.freehand(state.currentFreehand))
                }
                state.currentFreehand.removeAll()
                if let start = state.shapeStart, let current = state.shapeCurrent {
                    commitShape(from: start, to: current)
                }
                state.shapeStart = nil
                state.shapeCurrent = nil
            }

            if flags.contains(state.clearKey.flag) {
                state.clearDrawings()
            }

        case .keyDown:
            guard !state.isRecordingShortcut else { break }

            if state.isZoomActive, state.magnifierLockKey.matches(event) {
                state.isMagnifierLocked.toggle()
                break
            }

            for (tool, combo) in state.drawToolShortcuts where combo.matches(event) {
                state.drawTool = tool
                break
            }

            recordKeystrokeForOverlay(event)

        case .scrollWheel:
            guard state.isZoomActive, event.modifierFlags.contains(.command) else { break }
            adjustZoomFactor(with: event)

        default:
            break
        }
    }

    private func updateMouseLocation() {
        state.mouseLocation = NSEvent.mouseLocation
        guard state.multiDisplayPingEnabled, LicenseManager.shared.isUnlocked else { return }
        let current = NSScreen.screens.first(where: { $0.frame.contains(state.mouseLocation) })
        if current !== lastScreen {
            lastScreen = current
            if current != nil {
                addClickEffect(at: state.mouseLocation, kind: .screenFound)
            }
        }
    }

    private func addClickEffect(at point: NSPoint, kind: AppState.ClickKind) {
        guard state.clickEffectsEnabled, LicenseManager.shared.isUnlocked else { return }
        state.clickEffects.append(AppState.ClickEffect(point: point, kind: kind, time: ProcessInfo.processInfo.systemUptime))
    }

    /// Shows the pressed combo near the cursor, but ONLY when it includes
    /// ⌘/⌃/⌥ — a deliberate, non-negotiable filter. Without it this would
    /// echo every single key the user types, anywhere, including a
    /// password field; requiring a "shortcut-shaped" modifier keeps this
    /// a tutorial aid, never a keylogger.
    private func recordKeystrokeForOverlay(_ event: NSEvent) {
        guard state.keystrokeOverlayEnabled, LicenseManager.shared.isUnlocked else { return }
        let shortcutMods: NSEvent.ModifierFlags = [.command, .control, .option]
        guard !event.modifierFlags.intersection(shortcutMods).isEmpty else { return }
        state.lastKeystroke = AppState.KeyCombo.from(event)
        state.lastKeystrokeTime = ProcessInfo.processInfo.systemUptime
    }

    /// ⌘+Scroll while the Zoom key is held nudges the magnification live.
    /// Trackpad deltas are fine-grained (`hasPreciseScrollingDeltas`); a
    /// plain mouse wheel reports coarse "line" deltas — each gets its own
    /// sensitivity so both feel comparably fine, not one twitchy and the
    /// other unresponsive. Direction: scrolling up zooms in — this is a
    /// global/local MONITOR, same as every other input hook in this app,
    /// so it never blocks the scroll from also reaching whatever's under
    /// the cursor (see OverlayWindow's "never steal clicks" comment).
    private func adjustZoomFactor(with event: NSEvent) {
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.01 : 0.15
        let range = AppState.zoomFactorRange
        let proposed = state.zoomFactor + event.scrollingDeltaY * sensitivity
        state.zoomFactor = min(range.upperBound, max(range.lowerBound, proposed))
    }

    private func commitShape(from start: NSPoint, to end: NSPoint) {
        // Ignore accidental clicks with no real drag.
        guard hypot(end.x - start.x, end.y - start.y) > 4 else { return }
        switch state.drawTool {
        case .freehand: break
        case .arrow: state.drawItems.append(.arrow(start, end))
        case .ellipse: state.drawItems.append(.ellipse(start, end))
        case .rectangle: state.drawItems.append(.rectangle(start, end))
        }
    }
}
