import Foundation
import AppKit

/// Deschide ghidul de utilizare PDF — un singur fișier, RO/EN/ES una după
/// alta (nu 3 fișiere separate ca la GDCPluginManager Client; convenția
/// stabilită deja de installer/generate_pdf.py pentru acest repo, păstrată
/// aici ca să nu divergă). NSWorkspace.open respectă mereu aplicația
/// implicită a userului pentru PDF (de obicei Preview).
///
/// Generat cu `installer/generate_pdf.py` — rulează scriptul din nou și
/// suprascrie `Resources/Instructiuni-CursorProGDC.pdf` la orice schimbare
/// de conținut sau de funcționalitate a aplicației.
enum HelpGuide {
    static func openPDF() {
        // Bundle.module (nu Bundle.main) — resursele SPM ale acestui target
        // se instalează într-un .bundle separat, copiat de build_app.sh în
        // Contents/Resources/ lângă executabil.
        if let url = Bundle.module.url(forResource: "Instructiuni-CursorProGDC", withExtension: "pdf") {
            NSWorkspace.shared.open(url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Ghidul nu e încă disponibil"
        alert.informativeText = "Fișierul PDF de ghid nu a fost încă adăugat la această versiune a aplicației."
        alert.alertStyle = .informational
        alert.runModal()
    }
}
