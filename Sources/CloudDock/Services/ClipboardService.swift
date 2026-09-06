import AppKit
import Foundation

struct ClipboardHistoryItem: Identifiable, Equatable {
    let id: UUID
    let text: String
}

struct ClipboardSnapshot: Equatable {
    var text: String

    static let empty = ClipboardSnapshot(text: "")
}

final class ClipboardService: ObservableObject {
    @Published private(set) var snapshot = ClipboardSnapshot.empty
    @Published private(set) var history: [ClipboardHistoryItem] = []

    private var lastChangeCount = NSPasteboard.general.changeCount
    private let historyLimit = 10

    func refresh() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount
        let text = pasteboard.string(forType: .string) ?? ""
        addToHistory(text)
    }

    func copy(_ item: ClipboardHistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func clearHistory() {
        snapshot = .empty
        history = []
    }

    private func addToHistory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let masked = maskSensitiveText(String(trimmed.prefix(160)))
        snapshot = ClipboardSnapshot(text: masked)
        history.removeAll { $0.text == masked }
        history.insert(ClipboardHistoryItem(id: UUID(), text: masked), at: 0)
        history = Array(history.prefix(historyLimit))
    }

    private func maskSensitiveText(_ text: String) -> String {
        let lowercased = text.lowercased()
        let sensitiveMarkers = [
            "password",
            "passwd",
            "token",
            "secret",
            "api_key",
            "apikey",
            "bearer ",
            "ghp_",
            "sk-"
        ]

        let sensitivePatterns = [
            #"AKIA[0-9A-Z]{16}"#,
            #"[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"#,
            #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
            #"[?&](token|key|secret|password|signature)=[^&\s]+"#,
            #"[A-Za-z0-9+/=_-]{48,}"#
        ]

        let hasSensitiveMarker = sensitiveMarkers.contains(where: lowercased.contains)
        let hasSensitivePattern = sensitivePatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }

        return hasSensitiveMarker || hasSensitivePattern ? "Sensitive clipboard text hidden" : text
    }
}
