import AppKit
import Combine

// MARK: - Persistenta preferintelor (2026-09-11)
//
// GASIT LA AUDIT, nu presupus: `AppState` nu salva NIMIC. Fiecare preferinta
// — culoarea halo-ului, dimensiunea, nivelul de zoom, tastele configurate —
// se pierdea la fiecare inchidere a aplicatiei si revenea la valoarea din cod.
//
// A devenit blocant o data cu marirea plajelor (halo pana la 400px, lupa pana
// la 900px): o unealta pe care o reglezi pentru monitorul si sala ta, si care
// uita totul la repornire, nu e utilizabila profesional — exact scenariul
// pentru care au fost cerute valorile mari.
//
// Implementare deliberat SIMPLA, in spiritul restului aplicatiei: un singur
// `objectWillChange` -> scriere amanata, fara `@AppStorage` per proprietate
// (ar fi cerut rescrierea fiecarei declaratii din AppState si ar fi rupt
// `@Published`-urile de care depind overlay-ul si InputMonitor-ul).

extension AppState {
    private static let defaultsKeyPrefix = "cursorpro.pref."

    /// Cheile persistate. Doar PREFERINTE — starea vie (pozitia cursorului,
    /// modurile active, desenele in curs) nu are ce cauta pe disc.
    private enum Key: String, CaseIterable {
        case haloEnabled, haloColor, haloDiameter, haloLineWidth, haloStyle
        case zoomFactor, zoomWindowDiameter
        case magnifierSmoothScaling, magnifierColorPickerEnabled
        case clickEffectsEnabled, clickEffectDuration
        case keystrokeOverlayEnabled, keystrokeScale, keystrokeOpacity, keystrokeDisplayDuration
        case keystrokePosition, keystrokeBackgroundOpacity
        case spotlightRadius, spotlightDimOpacity

        var storageKey: String { AppState.defaultsKeyPrefix + rawValue }
    }

    /// Citeste preferintele salvate. Orice valoare lipsa sau invalida lasa
    /// implicitul din cod neatins — fail-open, la fel ca restul aplicatiei:
    /// un `UserDefaults` corupt nu trebuie sa porneasca aplicatia intr-o
    /// stare ciudata, doar sa piarda personalizarea.
    func loadPreferences() {
        let d = UserDefaults.standard

        if d.object(forKey: Key.haloEnabled.storageKey) != nil {
            haloEnabled = d.bool(forKey: Key.haloEnabled.storageKey)
        }
        if let data = d.data(forKey: Key.haloColor.storageKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            haloColor = color
        }
        haloDiameter = clamped(d, Key.haloDiameter, haloDiameter, Self.haloDiameterRange)
        haloLineWidth = clamped(d, Key.haloLineWidth, haloLineWidth, Self.haloLineWidthRange)
        if let raw = d.string(forKey: Key.haloStyle.storageKey), let style = HaloStyle(rawValue: raw) {
            haloStyle = style
        }

        zoomFactor = clamped(d, Key.zoomFactor, zoomFactor, Self.zoomFactorRange)
        zoomWindowDiameter = clamped(d, Key.zoomWindowDiameter, zoomWindowDiameter, Self.zoomWindowDiameterRange)

        if d.object(forKey: Key.magnifierSmoothScaling.storageKey) != nil {
            magnifierSmoothScaling = d.bool(forKey: Key.magnifierSmoothScaling.storageKey)
        }
        if d.object(forKey: Key.magnifierColorPickerEnabled.storageKey) != nil {
            magnifierColorPickerEnabled = d.bool(forKey: Key.magnifierColorPickerEnabled.storageKey)
        }
        if d.object(forKey: Key.clickEffectsEnabled.storageKey) != nil {
            clickEffectsEnabled = d.bool(forKey: Key.clickEffectsEnabled.storageKey)
        }
        if d.object(forKey: Key.clickEffectDuration.storageKey) != nil {
            clickEffectDuration = min(1.2, max(0.2, d.double(forKey: Key.clickEffectDuration.storageKey)))
        }
        if d.object(forKey: Key.keystrokeOverlayEnabled.storageKey) != nil {
            keystrokeOverlayEnabled = d.bool(forKey: Key.keystrokeOverlayEnabled.storageKey)
        }
        // Intervalul s-a largit la 8.0; o valoare veche (max 2.0) ramane
        // valida si nu se pierde la citire.
        keystrokeScale = clamped(d, Key.keystrokeScale, keystrokeScale, 0.5...8.0)
        keystrokeBackgroundOpacity = clamped(d, Key.keystrokeBackgroundOpacity, keystrokeBackgroundOpacity, 0.0...1.0)
        if let raw = d.string(forKey: Key.keystrokePosition.storageKey),
           let position = KeystrokePosition(rawValue: raw) {
            keystrokePosition = position
        }
        keystrokeOpacity = clamped(d, Key.keystrokeOpacity, keystrokeOpacity, 0.2...1.0)
        if d.object(forKey: Key.keystrokeDisplayDuration.storageKey) != nil {
            keystrokeDisplayDuration = min(2.5, max(0.6, d.double(forKey: Key.keystrokeDisplayDuration.storageKey)))
        }
        spotlightRadius = clamped(d, Key.spotlightRadius, spotlightRadius, 40...600)
        spotlightDimOpacity = clamped(d, Key.spotlightDimOpacity, spotlightDimOpacity, 0.1...0.95)
    }

    /// Citeste o valoare numerica si o INCADREAZA in plaja curenta. Fara
    /// asta, o plaja restransa intr-o versiune viitoare ar lasa pe disc o
    /// valoare imposibila, iar slider-ul ar porni in afara barei.
    private func clamped(_ d: UserDefaults, _ key: Key, _ current: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        guard d.object(forKey: key.storageKey) != nil else { return current }
        let raw = CGFloat(d.double(forKey: key.storageKey))
        guard raw.isFinite else { return current }
        return min(range.upperBound, max(range.lowerBound, raw))
    }

    /// Salveaza tot. Apelat amanat (vezi `startPersistingPreferences`), ca o
    /// tragere continua de slider sa nu scrie de 120 de ori pe secunda.
    func savePreferences() {
        let d = UserDefaults.standard
        d.set(haloEnabled, forKey: Key.haloEnabled.storageKey)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: haloColor, requiringSecureCoding: true) {
            d.set(data, forKey: Key.haloColor.storageKey)
        }
        d.set(Double(haloDiameter), forKey: Key.haloDiameter.storageKey)
        d.set(Double(haloLineWidth), forKey: Key.haloLineWidth.storageKey)
        d.set(haloStyle.rawValue, forKey: Key.haloStyle.storageKey)
        d.set(Double(zoomFactor), forKey: Key.zoomFactor.storageKey)
        d.set(Double(zoomWindowDiameter), forKey: Key.zoomWindowDiameter.storageKey)
        d.set(magnifierSmoothScaling, forKey: Key.magnifierSmoothScaling.storageKey)
        d.set(magnifierColorPickerEnabled, forKey: Key.magnifierColorPickerEnabled.storageKey)
        d.set(clickEffectsEnabled, forKey: Key.clickEffectsEnabled.storageKey)
        d.set(clickEffectDuration, forKey: Key.clickEffectDuration.storageKey)
        d.set(keystrokeOverlayEnabled, forKey: Key.keystrokeOverlayEnabled.storageKey)
        d.set(Double(keystrokeScale), forKey: Key.keystrokeScale.storageKey)
        d.set(Double(keystrokeBackgroundOpacity), forKey: Key.keystrokeBackgroundOpacity.storageKey)
        d.set(keystrokePosition.rawValue, forKey: Key.keystrokePosition.storageKey)
        d.set(Double(keystrokeOpacity), forKey: Key.keystrokeOpacity.storageKey)
        d.set(keystrokeDisplayDuration, forKey: Key.keystrokeDisplayDuration.storageKey)
        d.set(Double(spotlightRadius), forKey: Key.spotlightRadius.storageKey)
        d.set(Double(spotlightDimOpacity), forKey: Key.spotlightDimOpacity.storageKey)
    }

    /// Porneste salvarea automata.
    ///
    /// ATENTIE, capcana evitata deliberat: NU se aboneaza la `objectWillChange`.
    /// `mouseLocation` e si el `@Published`, deci acel semnal se emite la
    /// FIECARE miscare de mouse (60-120 ori pe secunda, cat timp aplicatia
    /// ruleaza). Chiar si cu debounce, asta ar fi insemnat o scriere pe disc
    /// la fiecare 0.4s in permanenta, degeaba — aplicatia sta pornita toata
    /// ziua in bara de meniu.
    ///
    /// In schimb, ne abonam EXPLICIT doar la publisher-ele preferintelor.
    /// O preferinta noua adaugata in viitor trebuie adaugata si in lista de
    /// mai jos ca sa fie salvata — costul constient al acestei alegeri, in
    /// schimbul faptului ca nu scriem pe disc la fiecare tremur de mouse.
    func startPersistingPreferences() {
        let changes: [AnyPublisher<Void, Never>] = [
            $haloEnabled.map { _ in () }.eraseToAnyPublisher(),
            $haloColor.map { _ in () }.eraseToAnyPublisher(),
            $haloDiameter.map { _ in () }.eraseToAnyPublisher(),
            $haloLineWidth.map { _ in () }.eraseToAnyPublisher(),
            $haloStyle.map { _ in () }.eraseToAnyPublisher(),
            $zoomFactor.map { _ in () }.eraseToAnyPublisher(),
            $zoomWindowDiameter.map { _ in () }.eraseToAnyPublisher(),
            $magnifierSmoothScaling.map { _ in () }.eraseToAnyPublisher(),
            $magnifierColorPickerEnabled.map { _ in () }.eraseToAnyPublisher(),
            $clickEffectsEnabled.map { _ in () }.eraseToAnyPublisher(),
            $clickEffectDuration.map { _ in () }.eraseToAnyPublisher(),
            $keystrokeOverlayEnabled.map { _ in () }.eraseToAnyPublisher(),
            $keystrokeScale.map { _ in () }.eraseToAnyPublisher(),
            $keystrokeBackgroundOpacity.map { _ in () }.eraseToAnyPublisher(),
            $keystrokePosition.map { _ in () }.eraseToAnyPublisher(),
            $keystrokeOpacity.map { _ in () }.eraseToAnyPublisher(),
            $keystrokeDisplayDuration.map { _ in () }.eraseToAnyPublisher(),
            $spotlightRadius.map { _ in () }.eraseToAnyPublisher(),
            $spotlightDimOpacity.map { _ in () }.eraseToAnyPublisher()
        ]

        persistenceCancellable = Publishers.MergeMany(changes)
            // O tragere de slider emite zeci de valori; scriem o singura data,
            // la final.
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.savePreferences() }
    }
}
