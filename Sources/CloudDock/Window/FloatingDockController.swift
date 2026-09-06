import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingDockController {
    private let panel: CloudDockWindow
    private let hostingView: CloudDockHostingView
    private let viewModel: DockViewModel
    private var cancellables = Set<AnyCancellable>()
    private var outsideClickMonitor: Any?
    private var lastPosition: DockPosition
    private var lastPreferences: DockPreferences
    private var isApplyingFrame = false

    var isVisible: Bool {
        panel.isVisible
    }

    init(viewModel: DockViewModel) {
        self.viewModel = viewModel
        lastPosition = viewModel.preferences.position
        lastPreferences = viewModel.preferences

        panel = CloudDockWindow(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        hostingView = CloudDockHostingView(rootView: AnyView(DockRootView(viewModel: viewModel).preferredColorScheme(.dark)))
        hostingView.sizingOptions = []

        configurePanel()
        installContent()
        bindLayoutChanges()
        installOutsideClickMonitor()
        observePanelMoves()
    }

    func stop() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    func show() {
        let wasVisible = panel.isVisible
        if !viewModel.isDockOpen {
            viewModel.openDock()
        }
        if !wasVisible {
            applyShowLayout()
        }
        RuntimeLog.write("show frame=\(panel.frame) visible=\(panel.isVisible) level=\(panel.level.rawValue)")
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        RuntimeLog.write("shown frame=\(panel.frame) visible=\(panel.isVisible) level=\(panel.level.rawValue)")
    }

    func hide() {
        viewModel.hideDock()
        panel.orderOut(nil)
    }

    func applyPreferredPosition(animated: Bool) {
        applyPreferredLayout(animated: animated)
    }

    private func configurePanel() {
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.sharingType = .readOnly
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        applyWindowLevel()
    }

    private func installContent() {
        let size = currentSize()
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.setFrameSize(size)
        panel.contentView = hostingView
        panel.setContentSize(size)
        panel.setFrame(NSRect(origin: .zero, size: size), display: false)
    }

    private func bindLayoutChanges() {
        viewModel.appGroupsService.$groups
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.applyContentSizeLayout(animated: false)
                }
            }
            .store(in: &cancellables)

        viewModel.$isDockOpen
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.viewModel.isDockOpen {
                        self.panel.makeKeyAndOrderFront(nil)
                    } else {
                        self.panel.orderOut(nil)
                    }
                }
            }
            .store(in: &cancellables)

        viewModel.$widgets
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.applyContentSizeLayout(animated: true)
                }
            }
            .store(in: &cancellables)

        viewModel.$preferences
            .dropFirst()
            .sink { [weak self] preferences in
                DispatchQueue.main.async {
                    self?.applyPreferencesLayout(preferences)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.applyPreferredLayout(animated: true)
            }
            .store(in: &cancellables)
    }

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.viewModel.isDockOpen else {
                    return
                }

                let clickPoint = NSEvent.mouseLocation
                if !self.panel.frame.contains(clickPoint) {
                    self.viewModel.hideDock()
                }
            }
        }
    }

    private func applyPreferencesLayout(_ preferences: DockPreferences) {
        let previous = lastPreferences
        lastPreferences = preferences
        applyWindowLevel()

        if preferences.isOnlyManualOriginChanged(from: previous) {
            return
        }

        if preferences.position != lastPosition {
            lastPosition = preferences.position
            applyPreferredLayout(animated: true)
        } else {
            applyCurrentPositionLayout(animated: true)
        }
    }

    private func applyPreferredLayout(animated: Bool) {
        let size = currentSize()
        let origin = preferredOrigin(size: size)
        setFrame(NSRect(origin: origin, size: size), animated: animated)
    }

    private func applyCurrentPositionLayout(animated: Bool) {
        let size = currentSize()
        let origin = DockLayoutCalculator.clampedOrigin(panel.frame.origin, size: size, screen: targetScreen())
        setFrame(NSRect(origin: origin, size: size), animated: animated)
    }

    private func applyContentSizeLayout(animated: Bool) {
        let size = currentSize()
        let origin: NSPoint
        if viewModel.preferences.hasManualOrigin {
            origin = DockLayoutCalculator.clampedOrigin(panel.frame.origin, size: size, screen: targetScreen())
        } else {
            origin = DockLayoutCalculator.origin(size: size, position: viewModel.preferences.position, screen: targetScreen())
        }
        setFrame(NSRect(origin: origin, size: size), animated: animated)
    }

    private func applyShowLayout() {
        let size = currentSize()
        let origin: NSPoint
        if viewModel.preferences.hasManualOrigin {
            origin = preferredOrigin(size: size)
        } else {
            origin = DockLayoutCalculator.origin(size: size, position: viewModel.preferences.position, screen: targetScreen())
        }
        setFrame(NSRect(origin: origin, size: size), animated: false)
    }

    private func applyWindowLevel() {
        panel.level = viewModel.preferences.alwaysOnTop ? .floating : .normal
    }

    private func setFrame(_ frame: NSRect, animated: Bool) {
        RuntimeLog.write("setFrame animated=\(animated) frame=\(frame)")
        isApplyingFrame = true
        panel.setFrame(frame, display: true)
        panel.contentView?.setFrameSize(frame.size)
        hostingView.setFrameSize(frame.size)
        isApplyingFrame = false
    }

    private func currentSize() -> NSSize {
        let entries: [(String, DockWidgetID)] = viewModel.widgets.map { ("widget:\($0.id.rawValue)", $0.id) }
            + viewModel.appGroupsService.groups.map { ("group:\($0.id.uuidString)", .toolsPalette) }
        let saved = UserDefaults.standard.string(forKey: DockReordering.storageKey) ?? "[]"
        let order = (try? JSONDecoder().decode([String].self, from: Data(saved.utf8))) ?? []
        let sorted = entries.sorted {
            (order.firstIndex(of: $0.0) ?? Int.max) < (order.firstIndex(of: $1.0) ?? Int.max)
        }
        let size = DockLayoutCalculator.size(
            widgetIDs: sorted.map(\.1),
            isDockOpen: viewModel.isDockOpen,
            screen: targetScreen()
        )
        RuntimeLog.write("currentSize widgets=\(viewModel.widgets.map { $0.id.rawValue }) open=\(viewModel.isDockOpen) size=\(size)")
        return size
    }

    private func preferredOrigin(size: NSSize) -> NSPoint {
        let preferences = viewModel.preferences
        if let x = preferences.manualOriginX, let y = preferences.manualOriginY {
            let origin = NSPoint(x: x, y: y)
            let screen = DockLayoutCalculator.screen(containing: origin)
            if DockLayoutCalculator.isFrameVisible(NSRect(origin: origin, size: size), screen: screen) {
                return DockLayoutCalculator.clampedOrigin(origin, size: size, screen: screen)
            }
        }

        return DockLayoutCalculator.origin(
            size: size,
            position: preferences.position,
            screen: targetScreen()
        )
    }

    private func targetScreen() -> NSScreen? {
        if panel.isVisible {
            return DockLayoutCalculator.screen(containing: panel.frame.center)
        }
        return DockLayoutCalculator.screen(containing: NSEvent.mouseLocation)
    }

    private func observePanelMoves() {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: panel)
            .sink { [weak self] _ in
                guard let self,
                      self.panel.isVisible,
                      !self.isApplyingFrame else {
                    return
                }

                let screen = DockLayoutCalculator.screen(containing: self.panel.frame.center)
                let origin = DockLayoutCalculator.clampedOrigin(self.panel.frame.origin, size: self.panel.frame.size, screen: screen)
                self.viewModel.setManualDockOrigin(x: Double(origin.x), y: Double(origin.y))
            }
            .store(in: &cancellables)
    }
}

private extension DockPreferences {
    func isOnlyManualOriginChanged(from other: DockPreferences) -> Bool {
        var current = self
        var previous = other
        current.manualOriginX = nil
        current.manualOriginY = nil
        previous.manualOriginX = nil
        previous.manualOriginY = nil
        return current == previous
            && (manualOriginX != other.manualOriginX || manualOriginY != other.manualOriginY)
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}

final class CloudDockWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class CloudDockHostingView: NSHostingView<AnyView> {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
