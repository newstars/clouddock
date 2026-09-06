import Foundation

enum DockPosition: String, CaseIterable, Codable, Identifiable {
    case bottom
    case top
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: "Bottom"
        case .top: "Top"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

struct DockPreferences: Equatable {
    var widgetOrder: [DockWidgetID]
    var enabledWidgets: Set<DockWidgetID>
    var position: DockPosition
    var alwaysOnTop: Bool
    var transparency: Double
    var launchAtLogin: Bool
    var privacyMode: Bool
    var gitRepositoryPaths: [String]
    var manualOriginX: Double?
    var manualOriginY: Double?

    var hasManualOrigin: Bool {
        manualOriginX != nil && manualOriginY != nil
    }

    static let defaults = DockPreferences(
        widgetOrder: WidgetRegistry.configurableWidgets.map(\.id),
        enabledWidgets: Set(WidgetRegistry.defaultWidgetIDs),
        position: .bottom,
        alwaysOnTop: false,
        transparency: 0.88,
        launchAtLogin: false,
        privacyMode: false,
        gitRepositoryPaths: [],
        manualOriginX: nil,
        manualOriginY: nil
    )
}
