import AppKit

/// Manual "Check for Updates" — compares the running app's version
/// against the latest GitHub release tag and, if newer, offers a direct
/// link to download it. Not a silent/automatic updater (that needs a
/// signed appcast + Sparkle-style framework); this is the simple,
/// no-extra-infrastructure version: one click to check, one click to go
/// get the new build.
enum UpdateChecker {
    /// gordasgdc/cursorpro-gdc — BUG REAL gasit 2026-08-26: slug-ul vechi
    /// "cursorpro" (fara "-gdc") da 404 la orice verificare, de la inceputul
    /// repo-ului — niciun client CursorPro n-a primit vreodata o notificare
    /// de update, fail-open silentios (eroarea de retea era tratata identic
    /// cu "esec normal", fara alertare). Verifica din nou daca repo-ul e redenumit.
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/gordasgdc/cursorpro-gdc/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/gordasgdc/cursorpro-gdc/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Runs the check and shows the result (up to date / new version
    /// available / error) in a plain alert — called from the menu.
    static func checkAndShowAlert() {
        Task {
            let result = await fetchLatestTag()
            await MainActor.run {
                presentResult(result)
            }
        }
    }

    private enum Result {
        case upToDate
        case newVersion(String)
        case error
    }

    private static func fetchLatestTag() async -> Result {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return .error
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if isVersion(latest, newerThan: currentVersion) {
                return .newVersion(latest)
            }
            return .upToDate
        } catch {
            return .error
        }
    }

    /// Simple dotted-numeric version comparison ("1.10.0" > "1.9.0").
    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func presentResult(_ result: Result) {
        let alert = NSAlert()
        switch result {
        case .upToDate:
            alert.messageText = L.t("sidebar.general")
            alert.informativeText = String(format: L.t("update.upToDate"), currentVersion)
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .newVersion(let version):
            alert.messageText = L.t("menu.checkForUpdates")
            alert.informativeText = String(format: L.t("update.available"), version, currentVersion)
            alert.addButton(withTitle: L.t("update.download"))
            alert.addButton(withTitle: "OK")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(releasesPageURL)
            }
        case .error:
            alert.messageText = L.t("menu.checkForUpdates")
            alert.informativeText = L.t("update.error")
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
