import Foundation

/// Owns CursorPro's trial/license state: starts a 3-day trial on first
/// launch, persists an activated code once entered, and exposes whether
/// the app's real features should currently be unlocked. Gating happens
/// at one choke point (`isUnlocked`), checked by InputMonitor before it
/// ever turns on Halo/Spotlight/Draw/Zoom.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    static let productID = "cursorpro"
    static let trialDurationDays = 3

    @Published private(set) var isLicensed = false
    @Published private(set) var licenseCustomer = ""
    @Published private(set) var licenseExpiresAt: Int64 = 0 // 0 = perpetual
    @Published var activationError: String?

    private let defaults = UserDefaults.standard
    private let trialStartKey = "cursorpro_trial_start"

    private var activationFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CursorPro", isDirectory: true)
            .appendingPathComponent("license.txt")
    }

    private init() {
        if defaults.object(forKey: trialStartKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: trialStartKey)
        }
        loadSavedLicense()
    }

    var trialStartDate: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: trialStartKey))
    }

    /// Whole days left in the trial, rounded up — "3" for the whole
    /// first day, down to "0" once it's actually expired.
    var trialDaysRemaining: Int {
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let remaining = Double(Self.trialDurationDays) * 86400 - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    var isTrialActive: Bool { trialDaysRemaining > 0 }

    /// The single source of truth InputMonitor/AppDelegate check before
    /// turning on any real feature.
    var isUnlocked: Bool { isLicensed || isTrialActive }

    @discardableResult
    func activate(code: String) -> Bool {
        activationError = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch LicenseCore.validate(serial: trimmed, expectedProductID: Self.productID) {
        case .success(let payload):
            saveLicense(code: trimmed)
            applyLicense(payload: payload)
            return true
        case .failure(let error):
            activationError = Self.message(for: error)
            return false
        }
    }

    func deactivate() {
        isLicensed = false
        licenseCustomer = ""
        licenseExpiresAt = 0
        if let url = activationFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadSavedLicense() {
        guard let url = activationFileURL,
              let code = try? String(contentsOf: url, encoding: .utf8) else { return }
        if case .success(let payload) = LicenseCore.validate(serial: code, expectedProductID: Self.productID) {
            applyLicense(payload: payload)
        }
    }

    private func applyLicense(payload: LicenseCore.Payload) {
        isLicensed = true
        licenseCustomer = payload.customer
        licenseExpiresAt = payload.expiresAt
    }

    private func saveLicense(code: String) {
        guard let url = activationFileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? code.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func message(for error: LicenseCore.ValidationError) -> String {
        switch error {
        case .malformedCode: return L.t("license.error.malformed")
        case .badSignature: return L.t("license.error.badSignature")
        case .wrongProduct: return L.t("license.error.wrongProduct")
        case .expired: return L.t("license.error.expired")
        }
    }
}
