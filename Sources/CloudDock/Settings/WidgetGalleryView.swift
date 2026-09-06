import SwiftUI

struct WidgetGalleryView: View {
    @ObservedObject var viewModel: DockViewModel
    @State private var searchText = ""

    private var groupedWidgets: [(WidgetCategory, [DockWidgetDescriptor])] {
        WidgetCategory.allCases.compactMap { category in
            let widgets = WidgetRegistry.searchableWidgets(matching: searchText)
                .filter { $0.isAvailable && $0.category == category }
            return widgets.isEmpty ? nil : (category, widgets)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search widgets", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ForEach(groupedWidgets, id: \.0) { category, widgets in
                VStack(alignment: .leading, spacing: 8) {
                    Label(category.title, systemImage: iconName(for: category))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 10)], spacing: 10) {
                        ForEach(widgets) { widget in
                            WidgetGalleryCard(
                                descriptor: widget,
                                isEnabled: viewModel.preferences.enabledWidgets.contains(widget.id),
                                toggle: { viewModel.setWidget(widget.id, enabled: $0) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func iconName(for category: WidgetCategory) -> String {
        switch category {
        case .quickAccess: "square.grid.2x2"
        case .dailyFocus: "timer"
        case .macControls: "desktopcomputer"
        case .utility: "wrench.and.screwdriver"
        case .business: "chart.bar"
        case .developer: "chevron.left.forwardslash.chevron.right"
        case .cloud: "cloud"
        }
    }
}

@MainActor
private struct WidgetGalleryCard: View {
    let descriptor: DockWidgetDescriptor
    let isEnabled: Bool
    let toggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: descriptor.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)

                Spacer()

                if descriptor.isAvailable {
                    Toggle("", isOn: Binding(get: { isEnabled }, set: { toggle($0) }))
                        .labelsHidden()
                } else {
                    Text("Soon")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }

            Text(descriptor.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Text(descriptor.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(minHeight: 104, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isEnabled ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
        }
        .opacity(descriptor.isAvailable ? 1 : 0.62)
    }
}
