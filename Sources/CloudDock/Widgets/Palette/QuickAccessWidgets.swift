import AppKit
import SwiftUI

struct FavoritesWidgetView: View {
    @AppStorage("cloudDock.favoritePaths") private var storedPaths = "[]"
    @State private var isPresented = false
    @State private var error: String?

    private var paths: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(storedPaths.utf8))) ?? []
    }

    var body: some View {
        Button { isPresented.toggle() } label: {
            DockIconTile(accent: .yellow, isActive: isPresented) {
                Image(systemName: "folder.badge.star")
            }
        }
        .buttonStyle(.plain)
        .help("Files & Folders")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Files & Folders").font(.headline)
                    Spacer()
                    Button(action: chooseFiles) { Image(systemName: "plus") }.help("Add files or folders")
                }
                if paths.isEmpty { Text("No favorites").foregroundStyle(.secondary) }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(paths, id: \.self) { path in
                            HStack {
                                Button {
                                    if !NSWorkspace.shared.open(URL(fileURLWithPath: path)) {
                                        error = "Could not open \(URL(fileURLWithPath: path).lastPathComponent)."
                                    }
                                } label: {
                                    HStack {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                            .resizable().frame(width: 28, height: 28)
                                        Text(URL(fileURLWithPath: path).lastPathComponent).lineLimit(1)
                                        Spacer()
                                    }
                                }.buttonStyle(.plain).help(path)
                                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) } label: {
                                    Image(systemName: "magnifyingglass")
                                }.help("Reveal in Finder")
                                Button { save(paths.filter { $0 != path }) } label: {
                                    Image(systemName: "minus.circle")
                                }.help("Remove favorite")
                            }.frame(height: 34)
                        }
                    }
                }.frame(height: CGFloat(min(paths.count, 8)) * 42)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }.dockPopoverPanel(width: 340)
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        var updated = paths
        for url in panel.urls where !updated.contains(url.path) { updated.append(url.path) }
        save(updated)
    }

    private func save(_ paths: [String]) {
        guard let data = try? JSONEncoder().encode(paths), let value = String(data: data, encoding: .utf8) else { return }
        storedPaths = value
    }
}

struct RunningAppsWidgetView: View {
    @State private var isPresented = false
    @State private var apps: [NSRunningApplication] = []

    var body: some View {
        Button { refresh(); isPresented.toggle() } label: {
            DockIconTile(accent: .blue, isActive: isPresented) { Image(systemName: "app.badge") }
        }
        .buttonStyle(.plain)
        .help("Running Apps")
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Running Apps").font(.headline)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(apps, id: \.processIdentifier) { app in
                            Button {
                                app.activate(options: [])
                                isPresented = false
                            } label: {
                                HStack {
                                    Image(nsImage: app.icon ?? NSWorkspace.shared.icon(for: .application))
                                        .resizable().frame(width: 28, height: 28)
                                    Text(app.localizedName ?? "Application").lineLimit(1)
                                    Spacer()
                                    if app.isActive { Circle().fill(.green).frame(width: 6, height: 6) }
                                }.frame(height: 34)
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(height: CGFloat(min(apps.count, 8)) * 42)
            }.dockPopoverPanel(width: 280)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in if isPresented { refresh() } }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in if isPresented { refresh() } }
    }

    private func refresh() {
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
