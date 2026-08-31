import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Exposed so `ZoomWindowController` can find out which of our OWN
    /// windows are the full-screen transparent overlays (Halo/Spotlight/
    /// Draw) that must never appear inside the Zoom loupe — see
    /// `overlayWindowIDs` below for why this can't just be "every window
    /// owned by our process ID" anymore.
    private(set) static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private var overlayWindows: [OverlayWindow] = []
    private let inputMonitor = InputMonitor()
    private var zoomWindowController: ZoomWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var permissionsSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon, no app switcher entry

        // Refuse to run as a second instance. Two copies polling
        // ScreenCaptureKit/global input monitors at once is exactly the
        // kind of thing that floods macOS's permission system and makes
        // the app look broken/stuck — always keep exactly one running.
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: "com.gordasgdc.cursorpro")
            .filter { $0.processIdentifier != myPID }
        if let existing = others.first {
            existing.activate()
            NSApp.terminate(nil)
            return
        }

        buildOverlays()
        inputMonitor.start()
        zoomWindowController = ZoomWindowController()
        buildStatusItem()

        // Prompt for both permissions once, up front, rather than making
        // the user hunt for the menu — CursorPro is largely useless
        // without them.
        PermissionsChecker.requestAccessibilityIfNeeded()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebuildMenu),
            name: .cursorProLanguageChanged, object: nil
        )
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Explicit, desi implicit ar trebui sa fie deja true - hardening
        // defensiv (2026-08-25) pentru bug raportat de testeri: iconita
        // dispare instant dupa lansare, dar procesul ramane viu (vizibil
        // in Activity Monitor). Nereprodus pe aceasta masina dupa 15+
        // secunde de asteptare + verificare directa prin Accessibility
        // API (nu doar "pare sa mearga") - probabil specific unei
        // configuratii de sistem (ex. "Automatically hide and show the
        // menu bar" din Control Center, sau Stage Manager) de pe Mac-ul
        // testerului, nu un bug de cod reprodus aici. Acest log ramane
        // activ ca sa putem diagnostica exact daca reapare.
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "CursorPro")
            DebugLog.log("buildStatusItem: creat OK, image=\(button.image != nil), isVisible=\(statusItem.isVisible)")
        } else {
            DebugLog.log("buildStatusItem: statusItem.button e nil - simptom posibil pentru bug-ul iconitei disparute")
        }
        rebuildMenu()
    }

    /// Versiunea curentă (`CFBundleShortVersionString`) — cerută explicit
    /// 2026-08-25, "Directivă Permanentă Supremă": orice aplicație GDC
    /// TREBUIE să-și arate versiunea vizibil în UI, fără excepție.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    @objc private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "\(L.t("menu.title")) — v\(appVersion)", action: nil, keyEquivalent: "").isEnabled = false

        let license = LicenseManager.shared
        let licenseItem = NSMenuItem(title: licenseMenuLine(license), action: #selector(openLicense), keyEquivalent: "")
        licenseItem.target = self
        if !license.isLicensed {
            licenseItem.image = NSImage(systemSymbolName: license.isTrialActive ? "clock.fill" : "exclamationmark.triangle.fill", accessibilityDescription: nil)
        }
        menu.addItem(licenseItem)
        menu.addItem(.separator())

        let haloItem = NSMenuItem(title: L.t("menu.halo"), action: #selector(toggleHalo), keyEquivalent: "")
        haloItem.state = AppState.shared.haloEnabled ? .on : .off
        haloItem.target = self
        menu.addItem(haloItem)

        let drawToolItem = NSMenuItem(title: L.t("menu.drawTool"), action: nil, keyEquivalent: "")
        let drawToolSubmenu = NSMenu()
        for tool in AppState.DrawTool.allCases {
            let shortcut = AppState.shared.drawToolShortcuts[tool]?.label ?? ""
            let title = shortcut.isEmpty ? tool.displayName : "\(tool.displayName)  (\(shortcut))"
            let item = NSMenuItem(title: title, action: #selector(selectDrawTool(_:)), keyEquivalent: "")
            item.image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil)
            item.state = AppState.shared.drawTool == tool ? .on : .off
            item.representedObject = tool
            item.target = self
            drawToolSubmenu.addItem(item)
        }
        drawToolItem.submenu = drawToolSubmenu
        menu.addItem(drawToolItem)

        menu.addItem(.separator())

        let permItem = NSMenuItem(title: L.t("menu.permissions"), action: nil, keyEquivalent: "")
        let permSubmenu = NSMenu()
        permSubmenu.delegate = self
        permItem.submenu = permSubmenu
        menu.addItem(permItem)
        permissionsSubmenu = permSubmenu
        refreshPermissionsSubmenu()

        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("menu.preferences"), action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L.t("sidebar.help"), action: #selector(openHelp), keyEquivalent: "?").target = self
        menu.addItem(withTitle: L.t("menu.checkForUpdates"), action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L.t("menu.quit"), action: #selector(quit), keyEquivalent: "q").target = self

        statusItem.menu = menu
    }

    private func licenseMenuLine(_ license: LicenseManager) -> String {
        if license.isLicensed { return "✅ " + L.t("license.status.licensed") }
        if license.isTrialActive {
            return "🕐 " + String(format: L.t("license.status.trial.daysLeft"), license.trialDaysRemaining)
        }
        return "⚠️ " + L.t("license.status.expired")
    }

    @objc private func openLicense() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showLicense()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkAndShowAlert()
    }

    // Re-check live status every time the Permissions submenu is about to
    // be shown, so it never displays a stale answer.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == permissionsSubmenu {
            refreshPermissionsSubmenu()
        }
    }

    private func refreshPermissionsSubmenu() {
        guard let submenu = permissionsSubmenu else { return }
        submenu.removeAllItems()

        submenu.addItem(statusItem(
            title: L.t("perm.accessibility"),
            granted: PermissionsChecker.isAccessibilityTrusted,
            action: #selector(openAccessibilitySettings)
        ))
        submenu.addItem(statusItem(
            title: L.t("perm.screenRecording"),
            granted: PermissionsChecker.isScreenRecordingGranted,
            action: #selector(openScreenRecordingSettings)
        ))
    }

    private func statusItem(title: String, granted: Bool, action: Selector) -> NSMenuItem {
        let dot = granted ? "🟢" : "🔴"
        let status = granted ? L.t("perm.granted") : L.t("perm.missing")
        let item = NSMenuItem(title: "\(dot) \(title) — \(status)", action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openAccessibilitySettings() {
        if !PermissionsChecker.isAccessibilityTrusted {
            PermissionsChecker.requestAccessibilityIfNeeded()
        }
        PermissionsChecker.openAccessibilitySettings()
    }

    @objc private func openScreenRecordingSettings() {
        if !PermissionsChecker.isScreenRecordingGranted {
            PermissionsChecker.requestScreenRecordingIfNeeded()
        }
        PermissionsChecker.openScreenRecordingSettings()
    }

    @objc private func toggleHalo(_ sender: NSMenuItem) {
        AppState.shared.haloEnabled.toggle()
        sender.state = AppState.shared.haloEnabled ? .on : .off
    }

    @objc private func selectDrawTool(_ sender: NSMenuItem) {
        guard let tool = sender.representedObject as? AppState.DrawTool else { return }
        AppState.shared.drawTool = tool
        rebuildMenu()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.show()
    }

    @objc private func openHelp() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showHelp()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func screensChanged() {
        buildOverlays()
    }

    /// Window numbers of the always-on, full-screen transparent overlay
    /// windows (Halo cursor / Spotlight / Draw) — these must be excluded
    /// from ScreenCaptureKit's Zoom capture (they're invisible passthrough
    /// windows that would otherwise show up as a weird flat tint over
    /// everything in the loupe). Anything else CursorPro owns — the
    /// Preferences window, the update-progress window — is a REAL window
    /// the user can legitimately point the Zoom magnifier at, and must
    /// stay visible in the capture.
    var overlayWindowIDs: [CGWindowID] {
        overlayWindows.map { CGWindowID($0.windowNumber) }
    }

    private func buildOverlays() {
        for w in overlayWindows { w.orderOut(nil) }
        overlayWindows = NSScreen.screens.map { screen in
            let w = OverlayWindow(screen: screen)
            w.orderFrontRegardless()
            return w
        }
    }
}
