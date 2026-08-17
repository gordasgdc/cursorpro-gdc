import Foundation

/// Plain-file diagnostic logging, writing directly to
/// ~/Desktop/cursorpro_debug.log. Exists because NSLog/os_log output was
/// consistently not showing up in `log stream` captures on this machine
/// during development (unclear why — possibly a system log filtering
/// quirk) — a file we can just read is unambiguous. Not used for
/// anything user-facing; safe to leave in.
enum DebugLog {
    private static let url = FileManager.default
        .urls(for: .desktopDirectory, in: .userDomainMask).first?
        .appendingPathComponent("cursorpro_debug.log")

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        guard let url else { return }
        let line = "\(formatter.string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
