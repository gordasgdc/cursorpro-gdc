import AppKit

/// Watches mouse position, modifier-key state, and the reconfigurable
/// draw-tool shortcut keys system-wide (across every app, not just ours)
/// and updates `AppState` accordingly. Uses `NSEvent` global monitors.
/// Mouse-moved/dragged and flagsChanged don't need Accessibility, but
/// observing keyDown globally does — that's why CursorPro asks for
/// Accessibility up front; without it, mouse tracking/halo still work,
/// only the draw-tool keyboard shortcuts won't fire.
final class InputMonitor {
    private let state = AppState.shared
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp,
            .flagsChanged, .keyDown
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
            state.mouseLocation = NSEvent.mouseLocation
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
            state.mouseLocation = NSEvent.mouseLocation
            if state.isDrawActive && state.drawTool != .freehand {
                state.shapeStart = state.mouseLocation
                state.shapeCurrent = state.mouseLocation
            }

        case .leftMouseUp:
            state.mouseLocation = NSEvent.mouseLocation
            if state.isDrawActive, state.drawTool != .freehand, let start = state.shapeStart {
                commitShape(from: start, to: state.mouseLocation)
            }
            state.shapeStart = nil
            state.shapeCurrent = nil

        case .flagsChanged:
            let flags = event.modifierFlags
            // Trial expired, no license activated: real features stay
            // off no matter which key is held. The Preferences → License
            // page still works so the user can enter a code any time.
            let unlocked = LicenseManager.shared.isUnlocked

            let wasDrawing = state.isDrawActive
            state.isZoomActive = unlocked && flags.contains(state.zoomKey.flag)
            state.isDrawActive = unlocked && flags.contains(state.drawKey.flag)
            state.isSpotlightActive = unlocked && flags.contains(state.spotlightKey.flag)

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
            for (tool, combo) in state.drawToolShortcuts where combo.matches(event) {
                state.drawTool = tool
                break
            }

        default:
            break
        }
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
