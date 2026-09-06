import Foundation

final class DockPreferencesStore {
    private enum Key {
        static let widgetOrder = "cloudDock.widgetOrder"
        static let enabledWidgets = "cloudDock.enabledWidgets"
        static let position = "cloudDock.position"
        static let alwaysOnTop = "cloudDock.alwaysOnTop"
        static let transparency = "cloudDock.transparency"
        static let launchAtLogin = "cloudDock.launchAtLogin"
        static let privacyMode = "cloudDock.privacyMode"
        static let gitRepositoryPath = "cloudDock.gitRepositoryPath"
        static let gitRepositoryPaths = "cloudDock.gitRepositoryPaths"
        static let manualOriginX = "cloudDock.manualOriginX"
        static let manualOriginY = "cloudDock.manualOriginY"
        static let preferencesVersion = "cloudDock.preferencesVersion"
        static let nativeAppGrouping = "cloudDock.nativeAppGrouping.v1"
    }

    private let currentPreferencesVersion = 2

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPreferences() -> DockPreferences {
        let shouldRunLegacyDefaultMigration = defaults.integer(forKey: Key.preferencesVersion) < currentPreferencesVersion
        let enabledWidgets = loadEnabledWidgets(migrateLegacyDefaults: shouldRunLegacyDefaultMigration)
        var order = loadWidgetOrder(enabledWidgets: enabledWidgets, migrateLegacyDefaults: shouldRunLegacyDefaultMigration)
        if !defaults.bool(forKey: Key.nativeAppGrouping) {
            order = WidgetRegistry.groupingNativeApps(order)
            defaults.set(order.map(\.rawValue), forKey: Key.widgetOrder)
            defaults.set(true, forKey: Key.nativeAppGrouping)
        }

        return DockPreferences(
            widgetOrder: order,
            enabledWidgets: enabledWidgets,
            position: loadPosition(),
            alwaysOnTop: loadBool(Key.alwaysOnTop, default: DockPreferences.defaults.alwaysOnTop),
            transparency: loadDouble(Key.transparency, default: DockPreferences.defaults.transparency),
            launchAtLogin: loadBool(Key.launchAtLogin, default: DockPreferences.defaults.launchAtLogin),
            privacyMode: loadBool(Key.privacyMode, default: DockPreferences.defaults.privacyMode),
            gitRepositoryPaths: loadGitRepositoryPaths(),
            manualOriginX: loadOptionalDouble(Key.manualOriginX),
            manualOriginY: loadOptionalDouble(Key.manualOriginY)
        )
    }

    func savePreferences(_ preferences: DockPreferences) {
        defaults.set(currentPreferencesVersion, forKey: Key.preferencesVersion)
        defaults.set(preferences.widgetOrder.map(\.rawValue), forKey: Key.widgetOrder)
        defaults.set(preferences.enabledWidgets.map(\.rawValue), forKey: Key.enabledWidgets)
        defaults.set(preferences.position.rawValue, forKey: Key.position)
        defaults.set(preferences.alwaysOnTop, forKey: Key.alwaysOnTop)
        defaults.set(preferences.transparency, forKey: Key.transparency)
        defaults.set(preferences.launchAtLogin, forKey: Key.launchAtLogin)
        defaults.set(preferences.privacyMode, forKey: Key.privacyMode)
        defaults.set(preferences.gitRepositoryPaths, forKey: Key.gitRepositoryPaths)
        defaults.removeObject(forKey: Key.gitRepositoryPath)
        setOptionalDouble(preferences.manualOriginX, forKey: Key.manualOriginX)
        setOptionalDouble(preferences.manualOriginY, forKey: Key.manualOriginY)
    }

    private func loadWidgetOrder(enabledWidgets: Set<DockWidgetID>, migrateLegacyDefaults: Bool) -> [DockWidgetID] {
        if migrateLegacyDefaults, enabledWidgets == Set(WidgetRegistry.defaultWidgetIDs) {
            let remaining = WidgetRegistry.configurableWidgets.map(\.id).filter { !WidgetRegistry.defaultWidgetIDs.contains($0) }
            return WidgetRegistry.defaultWidgetIDs + remaining
        }

        guard let rawValues = defaults.array(forKey: Key.widgetOrder) as? [String] else {
            return WidgetRegistry.configurableWidgets.map(\.id)
        }

        let restored = rawValues.compactMap(DockWidgetID.init(rawValue:))
        let missing = WidgetRegistry.configurableWidgets.map(\.id).filter { !restored.contains($0) }
        let merged = restored + missing
        return merged.isEmpty ? WidgetRegistry.configurableWidgets.map(\.id) : merged
    }

    private func loadEnabledWidgets(migrateLegacyDefaults: Bool) -> Set<DockWidgetID> {
        guard let rawValues = defaults.array(forKey: Key.enabledWidgets) as? [String] else {
            return DockPreferences.defaults.enabledWidgets
        }

        let restored = Set(rawValues.compactMap(DockWidgetID.init(rawValue:))).filter { widgetID in
            WidgetRegistry.descriptor(for: widgetID)?.isAvailable == true
        }

        let standaloneTools: Set<DockWidgetID> = [.toolsPalette, .clipboard, .quickNote]
        let defaultishWidgets = WidgetRegistry.legacyDefaultWidgetIDs
            .union([.date, .pomodoro, .network, .disk, .battery])
            .union(standaloneTools)

        if migrateLegacyDefaults,
           restored.isSubset(of: defaultishWidgets),
           restored.count <= defaultishWidgets.count {
            return Set(WidgetRegistry.defaultWidgetIDs)
        }

        return restored.isEmpty ? DockPreferences.defaults.enabledWidgets : restored
    }

    private func loadPosition() -> DockPosition {
        guard let rawValue = defaults.string(forKey: Key.position),
              let position = DockPosition(rawValue: rawValue) else {
            return DockPreferences.defaults.position
        }
        return position
    }

    private func loadGitRepositoryPaths() -> [String] {
        if let paths = defaults.array(forKey: Key.gitRepositoryPaths) as? [String] {
            return paths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if let legacyPath = defaults.string(forKey: Key.gitRepositoryPath),
           !legacyPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [legacyPath]
        }

        return DockPreferences.defaults.gitRepositoryPaths
    }

    private func loadBool(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    private func loadDouble(_ key: String, default defaultValue: Double) -> Double {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.double(forKey: key)
    }

    private func loadOptionalDouble(_ key: String) -> Double? {
        defaults.object(forKey: key) == nil ? nil : defaults.double(forKey: key)
    }

    private func setOptionalDouble(_ value: Double?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
