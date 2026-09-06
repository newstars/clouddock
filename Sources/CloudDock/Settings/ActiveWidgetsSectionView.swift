import SwiftUI

struct ActiveWidgetsSectionView: View {
    @ObservedObject var viewModel: DockViewModel

    private var widgets: [DockWidgetDescriptor] {
        viewModel.preferences.widgetOrder.compactMap(WidgetRegistry.descriptor(for:)).filter(\.isAvailable)
    }

    var body: some View {
        List {
            ForEach(widgets) { descriptor in
                HStack(spacing: 10) {
                    Image(systemName: descriptor.symbolName)
                        .frame(width: 22)
                        .foregroundStyle(.secondary)
                    Toggle(descriptor.title, isOn: enabledBinding(for: descriptor.id))
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .help("Drag to reorder")
                }
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .onMove(perform: moveWidgets)
        }
        .listStyle(.inset)
        .accessibilityLabel("Widget order")
    }

    private func enabledBinding(for widgetID: DockWidgetID) -> Binding<Bool> {
        Binding(
            get: { viewModel.preferences.enabledWidgets.contains(widgetID) },
            set: { viewModel.setWidget(widgetID, enabled: $0) }
        )
    }

    private func moveWidgets(from source: IndexSet, to destination: Int) {
        let order = viewModel.preferences.widgetOrder
        let displayed = widgets.map(\.id)
        let indices = IndexSet(source.compactMap { order.firstIndex(of: displayed[$0]) })
        let target = destination < displayed.count
            ? (order.firstIndex(of: displayed[destination]) ?? order.count)
            : order.count
        viewModel.moveWidget(from: indices, to: target)
    }
}
