import SwiftUI

struct DockRootView: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var viewModel: DockViewModel
    @State private var isShowingDockMenu = false
    @AppStorage(DockReordering.storageKey) private var savedOrder = "[]"
    @State private var itemFrames: [String: CGRect] = [:]

    private var itemIDs: [String] {
        let current = viewModel.widgets.map { "widget:\($0.id.rawValue)" }
            + viewModel.appGroupsService.groups.map { "group:\($0.id.uuidString)" }
        let saved = (try? JSONDecoder().decode([String].self, from: Data(savedOrder.utf8))) ?? []
        var seen = Set<String>()
        return (saved + current).filter { current.contains($0) && seen.insert($0).inserted }
    }

    var body: some View {
        Group {
            if viewModel.isDockOpen {
                WidgetFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(itemIDs, id: \.self) { id in
                        dockItem(id)
                            .modifier(DockReorderGesture(id: id, space: "dock-order", move: reorder))
                    }
                }
                .coordinateSpace(name: "dock-order")
                .onPreferenceChange(DockItemFrames.self) { itemFrames = $0 }
                .onChange(of: savedOrder) { _, _ in viewModel.refreshDockLayout() }
                .padding(.leading, DockLayoutCalculator.dockDragHandleWidth)
                .padding(.trailing, DockLayoutCalculator.dockControlsWidth)
            } else {
                Button {
                    viewModel.openDock()
                } label: {
                    Image(systemName: "dock.rectangle")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Show CloudDock")
                .onHover { isHovering in
                    if isHovering {
                        viewModel.openDock()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.68 * viewModel.preferences.transparency), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isDockOpen {
                dockMenuButton
                    .padding(.trailing, 10)
                    .padding(.bottom, 9)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if viewModel.isDockOpen {
                DockDragHandle()
                    .padding(.leading, 10)
                    .padding(.bottom, 9)
            }
        }
        .onExitCommand {
            viewModel.hideDock()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudDockOpenSettings)) { _ in
            openSettings()
        }
    }

    private var dockMenuButton: some View {
        Button {
            isShowingDockMenu.toggle()
        } label: {
            DockIconTile(accent: .orange, isActive: isShowingDockMenu) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .help("CloudDock Menu")
        .popover(isPresented: $isShowingDockMenu, arrowEdge: .bottom) {
            dockMenuPopover
        }
    }

    private var dockMenuPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            Divider()

            dockMenuAction(title: "Hide CloudDock", systemImage: "eye.slash") {
                isShowingDockMenu = false
                viewModel.hideWindowAction?()
            }
            dockMenuAction(title: "Reset Position", systemImage: "scope") {
                isShowingDockMenu = false
                viewModel.resetPositionAction?()
            }

            Divider()

            dockMenuAction(title: "Quit CloudDock", systemImage: "power", role: .destructive) {
                viewModel.quitAction?()
            }
        }
        .font(.system(size: 13, weight: .medium))
        .dockPopoverPanel(width: 190)
    }

    private func dockMenuAction(title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func dockItem(_ id: String) -> some View {
        if let widget = viewModel.widgets.first(where: { "widget:\($0.id.rawValue)" == id }) {
            widgetView(for: widget)
        } else if let group = viewModel.appGroupsService.groups.first(where: { "group:\($0.id.uuidString)" == id }) {
            AppGroupTile(group: group, service: viewModel.appGroupsService)
        }
    }

    private func reorder(_ id: String, at location: CGPoint) {
        let ids = DockReordering.reordered(itemIDs, source: id, location: location, frames: itemFrames)
        guard let data = try? JSONEncoder().encode(ids), let value = String(data: data, encoding: .utf8) else { return }
        savedOrder = value
    }

    @ViewBuilder
    private func widgetView(for widget: DockWidgetDescriptor) -> some View {
        DockWidgetFactory(viewModel: viewModel).view(for: widget)
    }
}
