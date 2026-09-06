import Foundation
import Combine
import SwiftUI

@MainActor
final class DockViewModel: ObservableObject {
    @Published private(set) var widgets: [DockWidgetDescriptor]
    @Published var isDockOpen = false
    @Published private(set) var preferences: DockPreferences

    let systemMetricsService = SystemMetricsService()
    let appLauncherService = AppLauncherService()
    let gitStatusService = GitStatusService()
    let networkStatsService = NetworkStatsService()
    let diskStatsService = DiskStatsService()
    let clipboardService = ClipboardService()
    let processMonitorService = ProcessMonitorService()
    let batteryStatusService = BatteryStatusService()
    let quickNoteService = QuickNoteService()
    let appGroupsService = AppGroupsService()
    private var groupChanges: AnyCancellable?

    var openSettingsAction: (() -> Void)?
    var showWindowAction: (() -> Void)?
    var hideWindowAction: (() -> Void)?
    var resetPositionAction: (() -> Void)?
    var quitAction: (() -> Void)?

    private let preferencesStore: DockPreferencesStore
    private let loginItemService: LoginItemServicing
    private var refreshTask: Task<Void, Never>?

    init(preferencesStore: DockPreferencesStore, loginItemService: LoginItemServicing = LoginItemService()) {
        self.preferencesStore = preferencesStore
        self.loginItemService = loginItemService

        var loaded = preferencesStore.loadPreferences()
        loaded.launchAtLogin = loginItemService.isEnabled
        preferences = loaded
        widgets = Self.resolveWidgets(from: loaded)
        groupChanges = appGroupsService.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        systemMetricsService.refresh()
        gitStatusService.repositoryPaths = loaded.gitRepositoryPaths
        diskStatsService.refresh()
        clipboardService.refresh()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            refreshCommandBackedServices()
        }
        startRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
    }

    func openDock() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isDockOpen = true
        }
    }

    func hideDock() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isDockOpen = false
        }
    }

    func setDockPosition(_ position: DockPosition) {
        updatePreferences {
            $0.position = position
            $0.manualOriginX = nil
            $0.manualOriginY = nil
        }
        showWindowAction?()
    }

    func setAlwaysOnTop(_ isEnabled: Bool) {
        updatePreferences { $0.alwaysOnTop = isEnabled }
    }

    func setTransparency(_ transparency: Double) {
        updatePreferences { $0.transparency = min(max(transparency, 0.35), 1) }
    }

    func setWidget(_ widgetID: DockWidgetID, enabled: Bool) {
        guard WidgetRegistry.descriptor(for: widgetID)?.isAvailable == true else {
            return
        }

        updatePreferences { preferences in
            if enabled {
                preferences.enabledWidgets.insert(widgetID)
            } else {
                preferences.enabledWidgets.remove(widgetID)
            }
        }
        if enabled { showWindowAction?() }
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        UserDefaults.standard.removeObject(forKey: DockReordering.storageKey)
        updatePreferences { preferences in
            preferences.widgetOrder.move(fromOffsets: source, toOffset: destination)
        }
    }

    func refreshDockLayout() {
        widgets = Self.resolveWidgets(from: preferences)
    }

    func moveWidget(_ draggedID: DockWidgetID, before targetID: DockWidgetID, after: Bool = false) {
        guard draggedID != targetID,
              let sourceIndex = preferences.widgetOrder.firstIndex(of: draggedID),
              let targetIndex = preferences.widgetOrder.firstIndex(of: targetID) else {
            return
        }

        updatePreferences { preferences in
            let item = preferences.widgetOrder.remove(at: sourceIndex)
            let adjustedTarget = (sourceIndex < targetIndex ? targetIndex - 1 : targetIndex) + (after ? 1 : 0)
            preferences.widgetOrder.insert(item, at: adjustedTarget)
        }
    }

    func moveWidgetToEnd(_ draggedID: DockWidgetID) {
        guard let sourceIndex = preferences.widgetOrder.firstIndex(of: draggedID) else {
            return
        }

        updatePreferences { preferences in
            let item = preferences.widgetOrder.remove(at: sourceIndex)
            preferences.widgetOrder.append(item)
        }
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        let result = loginItemService.setEnabled(isEnabled)
        updatePreferences { $0.launchAtLogin = result }
    }

    func setPrivacyMode(_ isEnabled: Bool) {
        if isEnabled {
            clipboardService.clearHistory()
        }
        updatePreferences { $0.privacyMode = isEnabled }
    }

    func setGitRepositoryPaths(_ paths: [String]) {
        let cleaned = paths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let validPaths = RepositoryPickerService.validRepositoryPaths(cleaned)
        updatePreferences { $0.gitRepositoryPaths = validPaths }
        gitStatusService.repositoryPaths = validPaths
        gitStatusService.refresh()
    }

    func chooseGitRepository() {
        guard let paths = RepositoryPickerService.chooseRepositories() else {
            return
        }

        setGitRepositoryPaths(paths)
    }

    func setManualDockOrigin(x: Double, y: Double) {
        var updated = preferences
        updated.manualOriginX = x
        updated.manualOriginY = y
        persistPreferences(updated, refreshWidgets: false)
    }

    func resetManualDockOrigin() {
        var updated = preferences
        updated.manualOriginX = nil
        updated.manualOriginY = nil
        persistPreferences(updated, refreshWidgets: false)
    }

    func refreshCommandBackedServices() {
        systemMetricsService.refresh()
        gitStatusService.refresh()
        networkStatsService.refresh()
        processMonitorService.refresh()
        batteryStatusService.refresh()
    }

    private func startRefreshLoop() {
        refreshTask = Task { @MainActor in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                systemMetricsService.refresh()
                processMonitorService.refresh()
                if !preferences.privacyMode {
                    clipboardService.refresh()
                }

                tick += 1
                if tick % 3 == 0 {
                    networkStatsService.refresh()
                    batteryStatusService.refresh()
                }
                if tick % 8 == 0 {
                    gitStatusService.refresh()
                }
            }
        }
    }

    private func updatePreferences(_ mutate: (inout DockPreferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        persistPreferences(updated, refreshWidgets: true)
    }

    private func persistPreferences(_ updated: DockPreferences, refreshWidgets: Bool) {
        preferences = updated
        if refreshWidgets {
            widgets = Self.resolveWidgets(from: updated)
        }
        preferencesStore.savePreferences(updated)

    }

    private static func resolveWidgets(from preferences: DockPreferences) -> [DockWidgetDescriptor] {
        preferences.widgetOrder
            .filter { preferences.enabledWidgets.contains($0) }
            .compactMap(WidgetRegistry.descriptor)
            .filter(\.isAvailable)
    }
}
