import Foundation

final class QuickNoteService: ObservableObject {
    @Published private(set) var text: String

    private let defaults: UserDefaults
    private let key = "cloudDock.quickNoteText"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: key) ?? ""
    }

    func setText(_ text: String) {
        self.text = String(text.prefix(500))
        defaults.set(self.text, forKey: key)
    }
}
