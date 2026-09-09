import Foundation

struct DockRefreshPolicy {
    let enabled: Set<DockWidgetID>
    let isVisible: Bool
    let privacyMode: Bool

    var capturesClipboard: Bool {
        !privacyMode && (enabled.contains(.clipboard) || enabled.contains(.toolsPalette))
    }

    func refreshes(_ widget: DockWidgetID, tick: Int) -> Bool {
        guard isVisible, enabled.contains(widget) else { return false }
        switch widget {
        case .cpu, .memory: return true
        case .network, .battery: return tick % 3 == 0
        case .gitStatus: return tick % 8 == 0
        case .disk: return tick % 30 == 0
        default: return false
        }
    }
}
