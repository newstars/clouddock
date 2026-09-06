import AppKit
import Combine
import SwiftUI

struct DockAppGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var paths: [String]
}

@MainActor
final class AppGroupsService: ObservableObject {
    @Published private(set) var groups: [DockAppGroup] = []
    @Published var error: String?
    private let defaults: UserDefaults
    private let key = "cloudDock.appGroups.v1"
    private var icons: [String: NSImage] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let stored = try? JSONDecoder().decode([DockAppGroup].self, from: data) {
            var seen = Set<UUID>()
            groups = stored.filter { seen.insert($0.id).inserted }
        }
    }

    func create(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        groups.append(DockAppGroup(id: UUID(), name: String(name.prefix(60)), paths: []))
        save()
    }

    func rename(_ id: UUID, name: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groups[index].name = String(trimmed.prefix(60))
        save()
    }

    func remove(_ id: UUID) {
        groups.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        defaults.removeObject(forKey: DockReordering.storageKey)
        groups.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func move(_ source: UUID, before target: UUID, after: Bool = false) {
        guard source != target, let from = groups.firstIndex(where: { $0.id == source }),
              let to = groups.firstIndex(where: { $0.id == target }) else { return }
        let group = groups.remove(at: from)
        groups.insert(group, at: (from < to ? to - 1 : to) + (after ? 1 : 0))
        save()
    }

    func moveApp(_ source: String, relativeTo target: String, in id: UUID, after: Bool) {
        guard source != target, let index = groups.firstIndex(where: { $0.id == id }),
              let from = groups[index].paths.firstIndex(of: source),
              let to = groups[index].paths.firstIndex(of: target) else { return }
        let path = groups[index].paths.remove(at: from)
        groups[index].paths.insert(path, at: (from < to ? to - 1 : to) + (after ? 1 : 0))
        save()
    }

    func reorderApps(_ paths: [String], in id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }),
              paths.count == groups[index].paths.count,
              Set(paths) == Set(groups[index].paths) else { return }
        groups[index].paths = paths
        save()
    }

    func chooseApps(for id: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Add Apps to Group"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK,
              let index = groups.firstIndex(where: { $0.id == id }) else { return }
        for url in panel.urls where url.pathExtension.lowercased() == "app" {
            if !groups[index].paths.contains(url.path) { groups[index].paths.append(url.path) }
        }
        save()
    }

    func removeApp(_ path: String, from id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].paths.removeAll { $0 == path }
        save()
    }

    func icon(_ path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }

    func launch(_ path: String) {
        guard path.hasSuffix(".app"), FileManager.default.fileExists(atPath: path) else {
            error = "This application is no longer available."; return
        }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init()) { @Sendable [weak self] _, error in
            if error != nil {
                Task { @MainActor in self?.error = "The application could not be opened." }
            }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) { defaults.set(data, forKey: key) }
    }
}
