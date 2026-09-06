import AppKit
import SwiftUI

@main
struct CloudDockApp: App {
    @NSApplicationDelegateAdaptor(CloudDockAppDelegate.self) private var appDelegate
    @StateObject private var runtime = CloudDockRuntime.shared

    var body: some Scene {
        Settings {
            if let viewModel = runtime.viewModel {
                SettingsView(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(width: 420, height: 460)
            }
        }
    }
}

@MainActor
final class CloudDockAppDelegate: NSObject, NSApplicationDelegate {
    private var dockController: FloatingDockController?
    private var statusItem: NSStatusItem?
    private var acceptsDockReopen = false
    private(set) var viewModel: DockViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        RuntimeLog.write("applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.regular)

        if let iconURL = Bundle.main.url(forResource: "CloudDock", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: iconURL)
        }

        let store = DockPreferencesStore()
        let viewModel = DockViewModel(preferencesStore: store)
        let controller = FloatingDockController(viewModel: viewModel)
        viewModel.showWindowAction = { [weak controller] in
            controller?.show()
            controller?.applyPreferredPosition(animated: false)
        }
        viewModel.openSettingsAction = { [weak self] in
            self?.showSettings()
        }
        viewModel.hideWindowAction = { [weak controller] in
            controller?.hide()
        }
        viewModel.resetPositionAction = { [weak self] in
            self?.resetDockPosition()
        }
        viewModel.quitAction = {
            NSApp.terminate(nil)
        }
        dockController = controller
        self.viewModel = viewModel
        CloudDockRuntime.shared.viewModel = viewModel

        installMenuBarItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.acceptsDockReopen = true
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        RuntimeLog.write("applicationWillFinishLaunching")
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if acceptsDockReopen {
            toggleDock()
        }
        return false
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "CloudDock"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Dock", action: #selector(toggleDock), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetDockPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit CloudDock", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu

        statusItem = item
    }

    @objc private func toggleDock() {
        if dockController?.isVisible == true {
            hideDock()
        } else {
            showDock()
        }
    }

    private func showDock() {
        dockController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideDock() {
        dockController?.hide()
    }

    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .cloudDockOpenSettings, object: nil)
    }

    @objc private func resetDockPosition() {
        viewModel?.resetManualDockOrigin()
        dockController?.show()
        dockController?.applyPreferredPosition(animated: false)
    }

    @objc private func quit() {
        dockController?.stop()
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let cloudDockOpenSettings = Notification.Name("dev.clouddock.openSettings")
}
