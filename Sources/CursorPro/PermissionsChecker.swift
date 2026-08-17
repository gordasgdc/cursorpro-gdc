import AppKit
import ApplicationServices

/// Live status for the two macOS privacy permissions CursorPro actually
/// depends on:
///   - Accessibility: makes the global mouse/modifier-key monitors that
///     drive the Halo/Spotlight/Draw/Zoom modes reliable system-wide.
///   - Screen Recording: required by ScreenCaptureKit for the Zoom
///     magnifier specifically.
enum PermissionsChecker {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isScreenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system's own "Allow Accessibility access" prompt if not
    /// already trusted (only shows once per app identity; after a user
    /// denies it, macOS won't re-prompt — openAccessibilitySettings() is
    /// the fallback for that case).
    static func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    /// Triggers the system's own Screen Recording prompt (only fires the
    /// dialog the first time capture is actually attempted).
    static func requestScreenRecordingIfNeeded() {
        _ = CGRequestScreenCaptureAccess()
    }

    static func openAccessibilitySettings() {
        openSettings(pane: "com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        openSettings(pane: "com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func openSettings(pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
