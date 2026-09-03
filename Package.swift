// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CursorPro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CursorPro",
            path: "Sources/CursorPro",
            resources: [
                // Ghid PDF (RO/EN/ES, o singură pagină per limbă) — deschis
                // din meniul Ajutor și din HelpPane. Generat cu
                // installer/generate_pdf.py — rulează scriptul din nou și
                // suprascrie acest fișier la orice schimbare de conținut.
                .copy("Resources/Instructiuni-CursorProGDC.pdf"),
            ]
        )
    ]
)
