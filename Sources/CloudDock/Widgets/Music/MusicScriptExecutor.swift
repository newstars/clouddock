import Foundation

struct MusicScriptResult: Sendable {
    let text: String
    let data: Data
    let errorNumber: Int?
    let errorMessage: String?
}

enum MusicScriptExecutor {
    // All NSAppleScript instances stay on this queue; only value data crosses back to callers.
    private static let queue = DispatchQueue(label: "dev.clouddock.music-scripts", qos: .utility)

    static func execute(_ source: String) async -> MusicScriptResult {
        await withCheckedContinuation { continuation in
            queue.async {
                let result: MusicScriptResult = autoreleasepool {
                    guard let script = NSAppleScript(source: source) else {
                        return MusicScriptResult(text: "", data: Data(), errorNumber: -1,
                                                 errorMessage: "Could not prepare Music command.")
                    }
                    var error: NSDictionary?
                    let descriptor = script.executeAndReturnError(&error)
                    return MusicScriptResult(text: descriptor.stringValue ?? "", data: descriptor.data,
                        errorNumber: (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue,
                        errorMessage: error?[NSAppleScript.errorMessage] as? String)
                }
                continuation.resume(returning: result)
            }
        }
    }
}
