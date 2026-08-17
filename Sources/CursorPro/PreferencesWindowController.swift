import AppKit
import SwiftUI
import ServiceManagement

extension Notification.Name {
    fileprivate static let cursorProShowPrefPane = Notification.Name("cursorProShowPrefPane")
}

final class PreferencesWindowController: NSWindowController {
    convenience init() {
        let view = PreferencesView()
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L.t("prefs.title")
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 680, height: 480))
        window.minSize = NSSize(width: 600, height: 420)
        self.init(window: window)
    }

    func show() { show(pane: nil) }

    /// Opens the window (creating it if needed) and, if `pane` is given,
    /// jumps straight to that sidebar page — used by the "Help" menu item.
    private func show(pane: PrefPane?) {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let pane {
            NotificationCenter.default.post(name: .cursorProShowPrefPane, object: pane)
        }
    }

    func showHelp() { show(pane: .help) }
    func showLicense() { show(pane: .license) }
}

private enum PrefPane: String, CaseIterable, Identifiable {
    case general, halo, spotlight, draw, zoom, shortcuts, permissions, license, help
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L.t("sidebar.general")
        case .halo: return L.t("sidebar.halo")
        case .spotlight: return L.t("sidebar.spotlight")
        case .draw: return L.t("sidebar.draw")
        case .zoom: return L.t("sidebar.zoom")
        case .shortcuts: return L.t("sidebar.shortcuts")
        case .permissions: return L.t("sidebar.permissions")
        case .license: return L.t("sidebar.license")
        case .help: return L.t("sidebar.help")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .halo: return "circle.dashed"
        case .spotlight: return "flashlight.on.fill"
        case .draw: return "pencil.tip"
        case .zoom: return "plus.magnifyingglass"
        case .shortcuts: return "keyboard"
        case .permissions: return "lock.shield"
        case .license: return "key.fill"
        case .help: return "questionmark.circle"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject private var state = AppState.shared
    @State private var selection: PrefPane? = .general

    var body: some View {
        NavigationSplitView {
            List(PrefPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selection ?? .general {
                    case .general: generalPane
                    case .halo: haloPane
                    case .spotlight: spotlightPane
                    case .draw: drawPane
                    case .zoom: zoomPane
                    case .shortcuts: shortcutsPane
                    case .permissions: PermissionsPane()
                    case .license: LicensePane()
                    case .help: HelpPane()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 600, minHeight: 420)
        .onReceive(NotificationCenter.default.publisher(for: .cursorProShowPrefPane)) { note in
            if let pane = note.object as? PrefPane { selection = pane }
        }
    }

    // MARK: - General

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.general"))

            card {
                labeledRow(L.t("prefs.language")) {
                    Picker("", selection: $state.language) {
                        ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
                Divider()
                labeledRow(L.t("prefs.startAtLogin")) {
                    Toggle("", isOn: Binding(
                        get: { state.startAtLogin },
                        set: { newValue in
                            state.startAtLogin = newValue
                            try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        }
                    )).labelsHidden()
                }
            }
        }
    }

    // MARK: - Halo

    private var haloPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.halo"))
            card {
                labeledRow(L.t("prefs.enabled")) {
                    Toggle("", isOn: $state.haloEnabled).labelsHidden()
                }
                Divider()
                labeledRow(L.t("prefs.color")) {
                    ColorPicker("", selection: colorBinding(\.haloColor)).labelsHidden()
                }
                Divider()
                labeledRow(L.t("prefs.style")) {
                    Picker("", selection: $state.haloStyle) {
                        Text(L.t("prefs.style.ring")).tag(AppState.HaloStyle.ring)
                        Text(L.t("prefs.style.filled")).tag(AppState.HaloStyle.filled)
                        Text(L.t("prefs.style.crosshair")).tag(AppState.HaloStyle.crosshair)
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                Divider()
                sliderRow(L.t("prefs.size"), value: $state.haloDiameter, range: 12...80)
                Divider()
                sliderRow(L.t("prefs.lineThickness"), value: $state.haloLineWidth, range: 1...10)
            }
        }
    }

    // MARK: - Spotlight

    private var spotlightPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.spotlight"))
            card {
                sliderRow(L.t("prefs.radius"), value: $state.spotlightRadius, range: 40...400)
                Divider()
                sliderRow(L.t("prefs.dimAmount"), value: $state.spotlightDimOpacity, range: 0...1)
            }
        }
    }

    // MARK: - Draw

    private var drawPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.draw"))
            card {
                labeledRow(L.t("prefs.tool")) {
                    Picker("", selection: $state.drawTool) {
                        ForEach(AppState.DrawTool.allCases) { tool in
                            Label(tool.displayName, systemImage: tool.symbol).tag(tool)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                Divider()
                labeledRow(L.t("prefs.color")) {
                    ColorPicker("", selection: colorBinding(\.drawColor)).labelsHidden()
                }
                Divider()
                sliderRow(L.t("prefs.lineThickness"), value: $state.drawLineWidth, range: 1...12)
                Divider()
                labeledRow("") {
                    Button(L.t("prefs.clearAll"), role: .destructive) { state.clearDrawings() }
                }
            }
            Text(L.t("draw.tool.hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Zoom

    private var zoomPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.zoom"))
            card {
                labeledRow(L.t("prefs.zoomLevel")) {
                    Picker("", selection: $state.zoomFactor) {
                        ForEach(AppState.zoomFactorOptions, id: \.self) { factor in
                            Text("\(Int(factor))x").tag(factor)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
            }
            Text(L.t("prefs.zoomLevel.hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Shortcuts

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            paneTitle(L.t("sidebar.shortcuts"))
            card {
                labeledRow(L.t("prefs.key.zoom")) { keyPicker($state.zoomKey) }
                Divider()
                labeledRow(L.t("prefs.key.draw")) { keyPicker($state.drawKey) }
                Divider()
                labeledRow(L.t("prefs.key.spotlight")) { keyPicker($state.spotlightKey) }
                Divider()
                labeledRow(L.t("prefs.key.clear")) { keyPicker($state.clearKey) }
            }

            Text(L.t("shortcut.drawTools")).font(.headline)
            card {
                ForEach(Array(AppState.DrawTool.allCases.enumerated()), id: \.element) { index, tool in
                    if index > 0 { Divider() }
                    HStack(spacing: 14) {
                        DrawToolThumbnail(tool: tool)
                        Text(tool.displayName).frame(width: 130, alignment: .leading)
                        Spacer(minLength: 0)
                        ShortcutRecorderButton(tool: tool)
                    }
                }
            }
            Text(L.t("shortcut.drawTools.hint"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func keyPicker(_ binding: Binding<AppState.ModifierKey>) -> some View {
        Picker("", selection: binding) {
            ForEach(AppState.ModifierKey.allCases) { k in Text(k.displayName).tag(k) }
        }
        .labelsHidden()
        .frame(width: 200)
    }

    // MARK: - Shared layout helpers

    private func paneTitle(_ text: String) -> some View {
        Text(text).font(.title2).fontWeight(.semibold)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if !label.isEmpty {
                Text(label).frame(width: 160, alignment: .leading)
            }
            Spacer(minLength: 0)
            content()
        }
    }

    private func sliderRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label).frame(width: 160, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.0f", value.wrappedValue))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<AppState, NSColor>) -> Binding<Color> {
        Binding(
            get: { Color(state[keyPath: keyPath]) },
            set: { state[keyPath: keyPath] = NSColor($0) }
        )
    }
}

// MARK: - Permissions pane (its own view: needs local @State to refresh)

private struct PermissionsPane: View {
    @State private var accessibilityGranted = PermissionsChecker.isAccessibilityTrusted
    @State private var screenRecordingGranted = PermissionsChecker.isScreenRecordingGranted

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.t("sidebar.permissions")).font(.title2).fontWeight(.semibold)
            Text(L.t("perm.subtitle"))
                .font(.callout)
                .foregroundStyle(.secondary)

            permissionCard(
                icon: "figure.walk.circle",
                title: L.t("perm.accessibility"),
                why: L.t("perm.accessibility.why"),
                granted: accessibilityGranted,
                openAction: { PermissionsChecker.requestAccessibilityIfNeeded(); PermissionsChecker.openAccessibilitySettings() }
            )

            permissionCard(
                icon: "rectangle.inset.filled.and.person.filled",
                title: L.t("perm.screenRecording"),
                why: L.t("perm.screenRecording.why"),
                granted: screenRecordingGranted,
                openAction: { PermissionsChecker.requestScreenRecordingIfNeeded(); PermissionsChecker.openScreenRecordingSettings() }
            )

            Button(L.t("prefs.refresh")) { refresh() }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        accessibilityGranted = PermissionsChecker.isAccessibilityTrusted
        screenRecordingGranted = PermissionsChecker.isScreenRecordingGranted
    }

    @ViewBuilder
    private func permissionCard(icon: String, title: String, why: String, granted: Bool, openAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(granted ? .green : .orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    Circle().fill(granted ? Color.green : Color.red).frame(width: 9, height: 9)
                    Text(granted ? L.t("perm.granted") : L.t("perm.missing"))
                        .font(.callout)
                        .foregroundStyle(granted ? .green : .red)
                }
                Text(why)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !granted {
                Button(L.t("prefs.openSettings"), action: openAction)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

// MARK: - Draw tool thumbnail (live preview of what the shape looks like)

private struct DrawToolThumbnail: View {
    let tool: AppState.DrawTool
    @ObservedObject private var state = AppState.shared

    var body: some View {
        Canvas { context, size in
            let color = Color(state.drawColor)
            let w = size.width, h = size.height
            let style = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

            switch tool {
            case .freehand:
                var path = Path()
                path.move(to: CGPoint(x: w * 0.15, y: h * 0.7))
                path.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.3),
                               control1: CGPoint(x: w * 0.35, y: h * 0.05),
                               control2: CGPoint(x: w * 0.6, y: h * 0.95))
                context.stroke(path, with: .color(color), style: style)

            case .arrow:
                let start = CGPoint(x: w * 0.15, y: h * 0.8)
                let end = CGPoint(x: w * 0.82, y: h * 0.2)
                var shaft = Path()
                shaft.move(to: start)
                shaft.addLine(to: end)
                context.stroke(shaft, with: .color(color), style: style)

                let angle = atan2(end.y - start.y, end.x - start.x)
                let headLen: CGFloat = 7
                let headAngle: CGFloat = .pi / 6.5
                let p1 = CGPoint(x: end.x - headLen * cos(angle - headAngle), y: end.y - headLen * sin(angle - headAngle))
                let p2 = CGPoint(x: end.x - headLen * cos(angle + headAngle), y: end.y - headLen * sin(angle + headAngle))
                var head = Path()
                head.move(to: end)
                head.addLine(to: p1)
                head.addLine(to: p2)
                head.closeSubpath()
                context.fill(head, with: .color(color))

            case .ellipse:
                let rect = CGRect(x: w * 0.16, y: h * 0.18, width: w * 0.68, height: h * 0.64)
                context.stroke(Path(ellipseIn: rect), with: .color(color), style: style)

            case .rectangle:
                let rect = CGRect(x: w * 0.16, y: h * 0.18, width: w * 0.68, height: h * 0.64)
                context.stroke(Path(rect), with: .color(color), style: style)
            }
        }
        .frame(width: 42, height: 30)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

// MARK: - Shortcut recorder (click, then press the new key combo)

private struct ShortcutRecorderButton: View {
    let tool: AppState.DrawTool
    @ObservedObject private var state = AppState.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? L.t("shortcut.pressKey") : (state.drawToolShortcuts[tool]?.label ?? L.t("shortcut.none")))
                .frame(minWidth: 96)
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
        }
        .buttonStyle(.bordered)
        .help(L.t("shortcut.click.to.record"))
        .onDisappear { stopRecording(save: false) }
    }

    private func toggleRecording() {
        if isRecording { stopRecording(save: false) } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        state.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 0x35 { // Escape cancels without saving
                stopRecording(save: false)
                return nil
            }
            state.drawToolShortcuts[tool] = AppState.KeyCombo.from(event)
            stopRecording(save: true)
            return nil
        }
    }

    private func stopRecording(save: Bool) {
        isRecording = false
        state.isRecordingShortcut = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}

// MARK: - License

private struct LicensePane: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var codeField = ""
    @State private var justActivated = false

    private static let whatsAppURL = URL(string: "https://wa.me/34643109970?text=" +
        "Salut! Vreau să cumpăr o licență CursorPro.".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.t("sidebar.license")).font(.title2).fontWeight(.semibold)

            statusCard

            if !license.isLicensed {
                activationCard
                buyCard
            } else {
                Button(L.t("license.deactivate"), role: .destructive) { license.deactivate() }
            }
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: license.isLicensed ? "checkmark.seal.fill" : (license.isTrialActive ? "clock.fill" : "exclamationmark.triangle.fill"))
                .font(.system(size: 28))
                .foregroundStyle(license.isLicensed ? .green : (license.isTrialActive ? .orange : .red))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle).font(.headline)
                Text(statusBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var statusTitle: String {
        if license.isLicensed { return L.t("license.status.licensed") }
        if license.isTrialActive { return L.t("license.status.trial") }
        return L.t("license.status.expired")
    }

    private var statusBody: String {
        if license.isLicensed { return L.t("license.status.licensed.body") }
        if license.isTrialActive {
            let days = license.trialDaysRemaining
            return days <= 1 ? L.t("license.status.trial.lastDay") : String(format: L.t("license.status.trial.daysLeft"), days)
        }
        return L.t("license.status.expired.body")
    }

    private var activationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L.t("license.field.placeholder"), text: $codeField)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            if let error = license.activationError {
                Text(error).font(.callout).foregroundStyle(.red)
            }
            if justActivated {
                Label(L.t("license.activated.success"), systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
            }

            Button(L.t("license.activate")) {
                justActivated = license.activate(code: codeField)
                if justActivated { codeField = "" }
            }
            .disabled(codeField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var buyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("license.buy.title")).font(.headline)
            Text(L.t("license.buy.price")).font(.callout).foregroundStyle(.secondary)
            Button(L.t("license.buy.button")) { NSWorkspace.shared.open(Self.whatsAppURL) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

// MARK: - Help

private struct HelpPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.t("sidebar.help")).font(.title2).fontWeight(.semibold)
            Text(L.t("help.intro"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            helpSection(icon: "circle.dashed", titleKey: "help.halo.title", bodyKey: "help.halo.body")
            helpSection(icon: "flashlight.on.fill", titleKey: "help.spotlight.title", bodyKey: "help.spotlight.body")
            helpSection(icon: "pencil.tip", titleKey: "help.draw.title", bodyKey: "help.draw.body")
            helpSection(icon: "plus.magnifyingglass", titleKey: "help.zoom.title", bodyKey: "help.zoom.body")
            helpSection(icon: "keyboard", titleKey: "help.shortcuts.title", bodyKey: "help.shortcuts.body")
            helpSection(icon: "lock.shield", titleKey: "help.permissions.title", bodyKey: "help.permissions.body")
            helpSection(icon: "lightbulb", titleKey: "help.tips.title", bodyKey: "help.tips.body")
        }
    }

    @ViewBuilder
    private func helpSection(icon: String, titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.secondary)
                Text(L.t(titleKey)).font(.headline)
            }
            Text(L.t(bodyKey))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}
