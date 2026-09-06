import AppKit
import Foundation

struct LaunchableApp: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String?
}

@MainActor
final class AppLauncherService: ObservableObject {
    @Published private(set) var apps: [LaunchableApp]

    private let defaults: UserDefaults
    private let customAppsKey = "cloudDock.launcherApps"
    private let appOrderKey = "cloudDock.launcherAppOrder"
    private var iconCache: [String: NSImage] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        apps = Self.orderedApps(
            Self.defaultApps + Self.loadCustomApps(from: defaults, key: customAppsKey),
            defaults: defaults,
            key: appOrderKey
        )
    }

    func open(_ app: LaunchableApp) {
        if let path = app.path {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else if let bundleIdentifier = app.bundleIdentifier,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func icon(for app: LaunchableApp) -> NSImage {
        if let cached = iconCache[app.id] {
            return cached
        }

        let icon: NSImage
        if let path = app.path {
            icon = NSWorkspace.shared.icon(forFile: path)
        } else if let bundleIdentifier = app.bundleIdentifier,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .application)
        }

        iconCache[app.id] = icon
        return icon
    }

    func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = "Add Applications"
        panel.message = "Choose applications to add to CloudDock."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK else {
            return
        }

        let selectedApps = panel.urls.map { url in
            LaunchableApp(
                id: "custom-\(url.path)",
                name: url.deletingPathExtension().lastPathComponent,
                bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
                path: url.path
            )
        }

        addCustomApps(selectedApps)
    }

    func remove(_ app: LaunchableApp) {
        guard app.path != nil else {
            return
        }

        apps.removeAll { $0.id == app.id }
        iconCache.removeValue(forKey: app.id)
        saveApps()
    }

    func moveApp(_ draggedID: String, before targetID: String) {
        guard draggedID != targetID,
              let sourceIndex = apps.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = apps.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let item = apps.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        apps.insert(item, at: adjustedTarget)
        saveApps()
    }

    private func addCustomApps(_ selectedApps: [LaunchableApp]) {
        let existingIDs = Set(apps.map(\.id))
        let uniqueApps = selectedApps.filter { !existingIDs.contains($0.id) }
        guard !uniqueApps.isEmpty else {
            return
        }

        apps.append(contentsOf: uniqueApps)
        saveApps()
    }

    private func saveApps() {
        defaults.set(apps.map(\.id), forKey: appOrderKey)
        saveCustomApps()
    }

    private func saveCustomApps() {
        let custom = apps
            .filter { $0.path != nil }
            .map { StoredLaunchableApp(name: $0.name, bundleIdentifier: $0.bundleIdentifier, path: $0.path) }

        if let data = try? JSONEncoder().encode(custom) {
            defaults.set(data, forKey: customAppsKey)
        }
    }

    private static let defaultApps: [LaunchableApp] = [
        LaunchableApp(id: "finder", name: "Finder", bundleIdentifier: "com.apple.finder", path: nil),
        LaunchableApp(id: "terminal", name: "Terminal", bundleIdentifier: "com.apple.Terminal", path: nil),
        LaunchableApp(id: "settings", name: "Settings", bundleIdentifier: "com.apple.systempreferences", path: nil)
    ]

    private static func loadCustomApps(from defaults: UserDefaults, key: String) -> [LaunchableApp] {
        guard let data = defaults.data(forKey: key),
              let storedApps = try? JSONDecoder().decode([StoredLaunchableApp].self, from: data) else {
            return []
        }

        return storedApps.compactMap { app in
            guard let path = app.path, FileManager.default.fileExists(atPath: path) else {
                return nil
            }

            return LaunchableApp(
                id: "custom-\(path)",
                name: app.name,
                bundleIdentifier: app.bundleIdentifier,
                path: path
            )
        }
    }

    private static func orderedApps(_ apps: [LaunchableApp], defaults: UserDefaults, key: String) -> [LaunchableApp] {
        guard let storedOrder = defaults.array(forKey: key) as? [String] else {
            return apps
        }

        let byID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        let ordered = storedOrder.compactMap { byID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let missing = apps.filter { !orderedIDs.contains($0.id) }
        return ordered + missing
    }
}

private struct StoredLaunchableApp: Codable {
    var name: String
    var bundleIdentifier: String?
    var path: String?
}
