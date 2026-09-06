import SwiftUI

struct GitStatusWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var gitStatusService: GitStatusService
    let privacyMode: Bool
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: compactText, accent: statusAccent)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: statusAccent, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            expandedSummary
                .dockPopoverPanel(width: 230)
        }
    }

    private var compactText: String {
        privacyMode && !isShowingDetails ? "Git --" : gitStatusService.snapshot.compactText
    }

    private var expandedSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            if privacyMode {
                Text("Repository details hidden")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if gitStatusService.snapshot.availableRepositories.isEmpty {
                Text(gitStatusService.snapshot.message)
                    .font(.system(size: 11, weight: .medium))
                Text("Open Settings to choose repositories")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gitStatusService.snapshot.repositories.prefix(3)) { repository in
                    repositoryRow(repository)
                }
            }
        }
        .frame(width: 210, alignment: .leading)
    }

    private func repositoryRow(_ repository: GitRepositorySnapshot) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(repositoryAccent(repository))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(repository.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Text(repository.isAvailable ? "\(repository.branch)  \(repository.changedFiles) chg  +\(repository.ahead)/-\(repository.behind)" : "Unavailable")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
    }

    private var statusAccent: Color {
        let snapshot = gitStatusService.snapshot
        guard snapshot.isRepository else {
            return .secondary
        }

        return snapshot.changedFiles == 0 && snapshot.ahead == 0 && snapshot.behind == 0 ? .green : .orange
    }

    private func repositoryAccent(_ repository: GitRepositorySnapshot) -> Color {
        guard repository.isAvailable else {
            return .red
        }

        return repository.changedFiles == 0 && repository.ahead == 0 && repository.behind == 0 ? .green : .orange
    }
}
