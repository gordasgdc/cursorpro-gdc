import AppKit
import ApplicationServices
import Security

/// Live status for the two macOS privacy permissions CursorPro actually
/// depends on:
///   - Accessibility: makes the global mouse/modifier-key monitors that
///     drive the Halo/Spotlight/Draw/Zoom modes reliable system-wide.
///   - Screen Recording: required by ScreenCaptureKit for the Zoom
///     magnifier specifically.
enum PermissionsChecker {

    // MARK: - Stare curenta

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

    // MARK: - Permisiuni care "se pierd" la fiecare pornire
    //
    // DE CE exista tot ce urmeaza (cauza reala, verificata direct in baza de
    // date TCC a sistemului, nu presupusa):
    //
    // macOS nu retine permisiunea pentru "aplicatia din /Applications", ci
    // pentru o CERINTA DE SEMNATURA salvata in momentul acordarii. Daca binarul
    // e ulterior semnat cu ALTA identitate, cerinta salvata nu mai e
    // indeplinita: sistemul trateaza aplicatia ca pe una necunoscuta si cere
    // permisiunea din nou — LA FIECARE pornire — in timp ce in Setari de
    // sistem bifa ramane aprinsa, pentru ca randul vechi e inca acolo. De aici
    // si singura solutie pe care o gaseste userul: sa scoata intrarea si sa o
    // adauge la loc, de fiecare data.
    //
    // Reacordarea nu rezolva nimic cat timp randul invechit ramane in sistem.
    // Ce rezolva e stergerea lui (`tccutil reset`), dupa care urmatoarea
    // acordare se leaga de semnatura CURENTA si ramane valabila.

    private static let bundleID = Bundle.main.bundleIdentifier ?? "com.gordasgdc.cursorpro"
    private static let grantedBeforeKey = "cursorpro_permissions_granted_before"
    private static let lastIdentityKey = "cursorpro_last_signing_identity"
    private static let untrustedLaunchesKey = "cursorpro_consecutive_untrusted_launches"

    /// Identitatea cu care e semnat binarul care ruleaza ACUM. Pentru o
    /// aplicatie semnata Developer ID e identificatorul de echipa (stabil intre
    /// toate versiunile); pentru un binar semnat local, amprenta certificatului
    /// — care se schimba la trecerea de la unul la altul, exact cazul care
    /// invalideaza permisiunile.
    static var signingIdentity: String {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return "necunoscut" }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return "necunoscut"
        }
        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any] else { return "necunoscut" }
        if let team = info[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty {
            return "team:" + team
        }
        if let ident = info[kSecCodeInfoIdentifier as String] as? String {
            return "local:" + ident
        }
        return "necunoscut"
    }

    /// Ce trebuie facut la pornire. Separat de UI ca sa poata fi citit dintr-o
    /// privire si testat fara fereastra.
    enum LaunchAction {
        /// Tot e in regula — nu se arata nimic.
        case nothing
        /// Prima rulare (sau permisiune nerefuzata inca): se cere normal.
        case requestFirstTime
        /// Permisiunea a fost acordata candva, dar sistemul n-o mai recunoaste
        /// — cerand-o din nou nu se repara. Trebuie sters randul invechit.
        case repairStaleGrant
    }

    static func evaluateOnLaunch() -> LaunchAction {
        let defaults = UserDefaults.standard
        let trusted = isAccessibilityTrusted
        let identity = signingIdentity
        let previousIdentity = defaults.string(forKey: lastIdentityKey)
        defaults.set(identity, forKey: lastIdentityKey)

        if trusted {
            // Retinem ca a functionat cel putin o data, ca sa putem deosebi mai
            // tarziu "n-a acordat niciodata" de "a acordat, dar s-a rupt".
            defaults.set(true, forKey: grantedBeforeKey)
            defaults.set(0, forKey: untrustedLaunchesKey)
            return .nothing
        }

        let untrustedLaunches = defaults.integer(forKey: untrustedLaunchesKey) + 1
        defaults.set(untrustedLaunches, forKey: untrustedLaunchesKey)

        let grantedBefore = defaults.bool(forKey: grantedBeforeKey)
        let identityChanged = previousIdentity != nil && previousIdentity != identity
        // A doua pornire consecutiva fara incredere inseamna, practic mereu, o
        // intrare invechita: un user care tocmai a acordat permisiunea ar fi
        // pornit deja increzut. Pragul e 2, nu 1, ca sa nu speriem pe cineva
        // aflat la prima rulare, care n-a apucat inca sa bifeze nimic.
        if grantedBefore || identityChanged || untrustedLaunches >= 2 {
            return .repairStaleGrant
        }
        return .requestFirstTime
    }

    /// Sterge intrarile invechite ale acestei aplicatii din evidenta de
    /// permisiuni a sistemului. Urmatoarea acordare se va lega de semnatura
    /// curenta. Nu cere parola de administrator — sunt permisiunile propriei
    /// aplicatii, pentru propriul utilizator.
    @discardableResult
    static func resetStaleGrants() -> Bool {
        var allOK = true
        for service in ["Accessibility", "ScreenCapture", "ListenEvent"] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            p.arguments = ["reset", service, bundleID]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do {
                try p.run()
                p.waitUntilExit()
                // `ListenEvent` nu exista pe toate versiunile de macOS — un esec
                // acolo nu inseamna ca repararea a picat.
                if p.terminationStatus != 0 && service != "ListenEvent" { allOK = false }
            } catch {
                allOK = false
            }
        }
        UserDefaults.standard.set(false, forKey: grantedBeforeKey)
        return allOK
    }
}
