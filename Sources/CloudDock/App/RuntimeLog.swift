import Foundation

enum RuntimeLog {
    private static let logURL = URL(fileURLWithPath: "/private/tmp/clouddock-runtime.log")

    static func write(_ message: String) {
        #if !DEBUG
        guard ProcessInfo.processInfo.environment["CLOUDDOCK_RUNTIME_LOG"] == "1" else {
            return
        }
        #endif

        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}
