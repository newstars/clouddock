import SwiftUI

struct DockSettingsSectionView: View {
    @ObservedObject var viewModel: DockViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupView(title: "Dock") {
                Picker("Position", selection: positionBinding) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    viewModel.showWindowAction?()
                } label: {
                    Label("Show CloudDock", systemImage: "dock.rectangle")
                }

                Toggle("Always on top", isOn: alwaysOnTopBinding)

                VStack(alignment: .leading) {
                    Text("Transparency")
                    Slider(value: transparencyBinding, in: 0.35...1)
                }
            }

            SettingsGroupView(title: "General") {
                Toggle("Privacy mode", isOn: privacyModeBinding)
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }

            SettingsGroupView(title: "Developer") {
                HStack(spacing: 8) {
                    Text(gitRepositoryLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Choose...") {
                        viewModel.chooseGitRepository()
                    }
                }
            }
        }
    }

    private var positionBinding: Binding<DockPosition> {
        Binding(get: { viewModel.preferences.position }, set: { viewModel.setDockPosition($0) })
    }

    private var alwaysOnTopBinding: Binding<Bool> {
        Binding(get: { viewModel.preferences.alwaysOnTop }, set: { viewModel.setAlwaysOnTop($0) })
    }

    private var transparencyBinding: Binding<Double> {
        Binding(get: { viewModel.preferences.transparency }, set: { viewModel.setTransparency($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { viewModel.preferences.launchAtLogin }, set: { viewModel.setLaunchAtLogin($0) })
    }

    private var privacyModeBinding: Binding<Bool> {
        Binding(get: { viewModel.preferences.privacyMode }, set: { viewModel.setPrivacyMode($0) })
    }

    private var gitRepositoryLabel: String {
        let paths = viewModel.preferences.gitRepositoryPaths
        guard !paths.isEmpty else {
            return "No repositories selected"
        }

        if paths.count == 1 {
            return paths[0]
        }

        return "\(paths.count) repositories selected"
    }

}
