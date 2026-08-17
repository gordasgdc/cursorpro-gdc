import AppKit

extension Notification.Name {
    static let cursorProLanguageChanged = Notification.Name("cursorProLanguageChanged")
}

/// Shared, observable app state. Everything the overlay draws, and every
/// preference the user can change, lives here so the overlay views, the
/// input monitor, and the preferences window all read/write one source
/// of truth.
final class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Live pointer state (updated continuously by InputMonitor)
    @Published var mouseLocation: NSPoint = NSEvent.mouseLocation

    // MARK: - Mode flags (driven by held modifier keys)
    @Published var isSpotlightActive = false
    @Published var isDrawActive = false
    @Published var isZoomActive = false

    // MARK: - Halo appearance
    @Published var haloEnabled = true
    @Published var haloColor: NSColor = .systemYellow
    @Published var haloDiameter: CGFloat = 32
    @Published var haloLineWidth: CGFloat = 3
    @Published var haloStyle: HaloStyle = .ring

    enum HaloStyle: String, CaseIterable, Identifiable {
        case ring       // outline circle
        case filled     // solid filled circle
        case crosshair  // ring + crosshair ticks
        var id: String { rawValue }
    }

    // MARK: - Spotlight appearance
    @Published var spotlightRadius: CGFloat = 160
    @Published var spotlightDimOpacity: CGFloat = 0.75 // 0 = fully see-through, 1 = fully black

    // MARK: - Draw appearance
    @Published var drawColor: NSColor = .systemRed
    @Published var drawLineWidth: CGFloat = 4
    @Published var drawTool: DrawTool = .freehand

    /// Completed drawing items, in global (flipped-AppKit, origin
    /// bottom-left) screen coordinates.
    @Published var drawItems: [DrawItem] = []

    /// In-progress freehand trail (tool == .freehand, key held + mouse moving).
    var currentFreehand: [NSPoint] = []
    /// In-progress shape drag (tool == arrow/ellipse/rectangle, key held + mouse button down).
    var shapeStart: NSPoint?
    var shapeCurrent: NSPoint?

    enum DrawTool: String, CaseIterable, Identifiable {
        case freehand, arrow, ellipse, rectangle
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .freehand: return L.t("draw.tool.freehand")
            case .arrow: return L.t("draw.tool.arrow")
            case .ellipse: return L.t("draw.tool.ellipse")
            case .rectangle: return L.t("draw.tool.rectangle")
            }
        }

        var symbol: String {
            switch self {
            case .freehand: return "pencil.tip"
            case .arrow: return "arrow.up.right"
            case .ellipse: return "circle"
            case .rectangle: return "rectangle"
            }
        }
    }

    enum DrawItem {
        case freehand([NSPoint])
        case arrow(NSPoint, NSPoint)
        case ellipse(NSPoint, NSPoint)
        case rectangle(NSPoint, NSPoint)
    }

    /// A user-reconfigurable global keyboard shortcut: a physical key
    /// (matched by keyCode, layout-independent) plus modifiers. `label`
    /// is a display string computed once at record time.
    struct KeyCombo: Equatable {
        var keyCode: UInt16
        var modifiers: NSEvent.ModifierFlags
        var label: String

        static let relevantModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

        func matches(_ event: NSEvent) -> Bool {
            event.keyCode == keyCode &&
            event.modifierFlags.intersection(Self.relevantModifierMask) == modifiers
        }

        static func from(_ event: NSEvent) -> KeyCombo {
            KeyCombo(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags.intersection(relevantModifierMask),
                label: label(for: event)
            )
        }

        static func label(for event: NSEvent) -> String {
            var s = ""
            let flags = event.modifierFlags
            if flags.contains(.control) { s += "⌃" }
            if flags.contains(.option) { s += "⌥" }
            if flags.contains(.shift) { s += "⇧" }
            if flags.contains(.command) { s += "⌘" }
            s += keyName(for: event.keyCode, fallbackCharacters: event.charactersIgnoringModifiers)
            return s
        }

        private static func keyName(for keyCode: UInt16, fallbackCharacters: String?) -> String {
            if let name = keyCodeNames[keyCode] { return name }
            if let c = fallbackCharacters, !c.isEmpty { return c.uppercased() }
            return "#\(keyCode)"
        }

        private static let keyCodeNames: [UInt16: String] = [
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
            0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
            0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
            0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
            0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
            0x06: "Z",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5",
            0x61: "F6", 0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10",
            0x67: "F11", 0x6F: "F12",
            0x31: "Space", 0x30: "Tab", 0x35: "Esc", 0x24: "Return",
            0x33: "⌫", 0x7B: "←", 0x7C: "→", 0x7E: "↑", 0x7D: "↓",
        ]
    }

    /// Reconfigurable global shortcuts that instantly switch the active
    /// draw tool — independent of the draw-mode hold key, so during a
    /// live presentation you can pre-select a tool with one keystroke.
    @Published var drawToolShortcuts: [DrawTool: KeyCombo] = [
        .freehand: KeyCombo(keyCode: 0x12, modifiers: .option, label: "⌥1"),
        .arrow: KeyCombo(keyCode: 0x13, modifiers: .option, label: "⌥2"),
        .ellipse: KeyCombo(keyCode: 0x14, modifiers: .option, label: "⌥3"),
        .rectangle: KeyCombo(keyCode: 0x15, modifiers: .option, label: "⌥4"),
    ]
    /// True while the Preferences UI is capturing a new shortcut, so the
    /// global key monitor doesn't also fire tool-switches mid-recording.
    @Published var isRecordingShortcut = false

    // MARK: - Zoom appearance
    /// How strongly the loupe magnifies, as a plain factor (2x-6x) the
    /// user picks directly. The captured radius is derived from this and
    /// the fixed loupe window size — NOT set independently — so "zoom
    /// level" always means exactly what it says instead of two sliders
    /// (radius + factor) fighting over the same effective result.
    @Published var zoomFactor: CGFloat = 3
    static let zoomFactorOptions: [CGFloat] = [2, 3, 4, 5, 6]
    /// Fixed diameter of the loupe window, in points.
    static let zoomWindowDiameter: CGFloat = 360
    /// Radius, in points, of the source region captured around the cursor — derived from zoomFactor.
    var zoomRadius: CGFloat { Self.zoomWindowDiameter / (2 * zoomFactor) }

    // MARK: - Key bindings (as CGEventFlags-testable modifier keys)
    // .function (fn) is deliberately NOT used as a default: Apple overlays
    // that bit with arrow keys, F-keys, Delete, etc., and its held/released
    // state doesn't always reach third-party apps reliably — that's what
    // caused zoom to get stuck "on" indefinitely. Shift is a plain, solid
    // modifier with none of that baggage.
    @Published var zoomKey: ModifierKey = .shift
    @Published var drawKey: ModifierKey = .option
    @Published var spotlightKey: ModifierKey = .control
    @Published var clearKey: ModifierKey = .command

    enum ModifierKey: String, CaseIterable, Identifiable {
        case function, option, control, command, shift
        var id: String { rawValue }

        var flag: NSEvent.ModifierFlags {
            switch self {
            case .function: return .function
            case .option: return .option
            case .control: return .control
            case .command: return .command
            case .shift: return .shift
            }
        }

        var displayName: String {
            switch self {
            case .function: return L.t("key.function")
            case .option: return L.t("key.option")
            case .control: return L.t("key.control")
            case .command: return L.t("key.command")
            case .shift: return L.t("key.shift")
            }
        }
    }

    // MARK: - General
    @Published var startAtLogin = false
    @Published var language: AppLanguage = L.current {
        didSet {
            L.current = language
            NotificationCenter.default.post(name: .cursorProLanguageChanged, object: nil)
        }
    }

    private init() {}

    func clearDrawings() {
        drawItems.removeAll()
        currentFreehand.removeAll()
        shapeStart = nil
        shapeCurrent = nil
    }
}
