import AppKit

/// A borderless, transparent, click-through window that sits above
/// everything (including other apps in fullscreen) and spans exactly one
/// physical screen. We make one of these per connected screen so drawing
/// coordinates line up 1:1 with that screen's own frame.
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true // never steal clicks meant for real apps
        level = .screenSaver      // above normal windows, menu bar, and fullscreen apps
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        isReleasedWhenClosed = false

        let view = OverlayView(frame: screen.frame)
        contentView = view
    }
}
