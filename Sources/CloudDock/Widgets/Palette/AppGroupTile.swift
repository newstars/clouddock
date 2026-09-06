import SwiftUI

struct AppGroupTile: View {
    let group: DockAppGroup
    @ObservedObject var service: AppGroupsService
    @State private var presented = false
    @State private var appFrames: [String: CGRect] = [:]

    var body: some View {
        Button { presented.toggle() } label: {
            AppGroupPreview(group: group, service: service)
        }
        .buttonStyle(.plain)
        .help(group.name)
        .accessibilityLabel(group.name)
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(group.name).font(.headline).lineLimit(2)
                    Spacer()
                    Button { service.chooseApps(for: group.id) } label: { Image(systemName: "plus") }
                        .help("Add apps")
                }
                if group.paths.isEmpty { Text("No apps").foregroundStyle(.secondary) }
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 4), spacing: 12) {
                        ForEach(group.paths, id: \.self) { path in
                            Button { service.launch(path); presented = false } label: {
                                VStack(spacing: 4) {
                                    Image(nsImage: service.icon(path)).resizable().scaledToFit().frame(width: 48, height: 48)
                                    Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                                        .font(.caption).lineLimit(2).frame(height: 30)
                                }.frame(width: 76, height: 84)
                            }
                            .buttonStyle(.plain)
                            .modifier(DockReorderGesture(id: path, space: group.id.uuidString) { source, location in
                                let paths = DockReordering.reordered(group.paths, source: source, location: location, frames: appFrames)
                                service.reorderApps(paths, in: group.id)
                            })
                            .contextMenu {
                                Button("Remove from Group") { service.removeApp(path, from: group.id) }
                            }
                        }
                    }
                    .coordinateSpace(name: group.id.uuidString)
                    .onPreferenceChange(DockItemFrames.self) { appFrames = $0 }
                }.frame(height: min(CGFloat((group.paths.count + 3) / 4) * 96, 320))
            }.dockPopoverPanel(width: 356)
        }
    }
}

struct AppGroupPreview: View {
    let group: DockAppGroup
    @ObservedObject var service: AppGroupsService

    var body: some View {
        LazyVGrid(columns: [GridItem(.fixed(15), spacing: 1), GridItem(.fixed(15), spacing: 1)], spacing: 1) {
            ForEach(0..<4) { index in
                if index < group.paths.count {
                    Image(nsImage: service.icon(group.paths[index]))
                        .resizable().scaledToFit().frame(width: 15, height: 15)
                } else {
                    Color.clear.frame(width: 15, height: 15)
                }
            }
        }
        .frame(width: 38, height: 38)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.18)) }
        .frame(width: DockLayoutCalculator.iconWidgetWidth, height: DockTileMetrics.compactHeight)
        .contentShape(Rectangle())
    }
}
