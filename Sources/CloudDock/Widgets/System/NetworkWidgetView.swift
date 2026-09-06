import SwiftUI

struct NetworkWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var networkStatsService: NetworkStatsService
    let privacyMode: Bool
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: privacyMode && !isShowingDetails ? "NET --" : compactText, accent: .cyan)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .cyan, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(privacyMode ? "Hidden" : "Network")
                    .font(.system(size: 13, weight: .semibold))
                Text(privacyMode ? "Privacy mode" : detailText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .dockPopoverPanel(width: 240)
        }
    }

    private var compactText: String {
        "NET \(bytes(networkStatsService.snapshot.downloadBytesPerSecond))/s"
    }

    private var detailText: String {
        "Down \(bytes(networkStatsService.snapshot.downloadBytesPerSecond))/s  Up \(bytes(networkStatsService.snapshot.uploadBytesPerSecond))/s"
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}
