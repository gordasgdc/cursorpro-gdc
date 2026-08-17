// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CursorPro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CursorPro",
            path: "Sources/CursorPro"
        )
    ]
)
