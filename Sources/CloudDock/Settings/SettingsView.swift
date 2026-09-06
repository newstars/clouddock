import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: DockViewModel
    @State private var selectedTab = SettingsTab.dock

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Group {
                if selectedTab == .widgets {
                    ActiveWidgetsSectionView(viewModel: viewModel)
                } else if selectedTab == .groups {
                    AppGroupsSettingsView(service: viewModel.appGroupsService)
                } else {
                    ScrollView {
                        if selectedTab == .dock {
                            DockSettingsSectionView(viewModel: viewModel)
                        } else {
                            WidgetGalleryView(viewModel: viewModel)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 560, height: 560)
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case dock
    case widgets
    case gallery
    case groups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dock: "Dock"
        case .widgets: "Active"
        case .gallery: "Gallery"
        case .groups: "App Groups"
        }
    }
}
