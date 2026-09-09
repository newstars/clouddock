import AppKit

enum ClipboardTests {
    static func run() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let service = ClipboardService(pasteboard: board)
        func capture(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
            service.refresh()
        }
        let original = "  " + String(repeating: "example line\n", count: 40) + "  "
        capture(original)
        precondition(service.history.count == 1)
        precondition(service.history[0].preview.count == 160)
        service.copy(service.history[0])
        precondition(board.string(forType: .string) == original, "Copy must preserve full text and whitespace")
        service.refresh()
        precondition(service.history.count == 1)
        capture(String(repeating: "ordinary text ", count: 30) + "password=test")
        precondition(service.history.count == 1, "Scan beyond preview length")
        board.clearContents()
        board.setString("private value", forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        service.refresh()
        precondition(service.history.count == 1)
        capture(String(repeating: "abc ", count: 20_000))
        precondition(service.history.count == 1)
        for i in 0..<12 { capture("Entry \(i)") }
        precondition(service.history.count == 10)
        capture("Entry 11")
        precondition(service.history.count == 10)
        service.clearHistory()
        service.refresh()
        precondition(service.history.isEmpty)
        print("PASS: clipboard round-trip, bounds, privacy markers, full-text screening, deduplication, clear")
    }
}
