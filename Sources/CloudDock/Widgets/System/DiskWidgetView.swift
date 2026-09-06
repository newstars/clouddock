import SwiftUI

struct DiskWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var diskStatsService: DiskStatsService
    let privacyMode: Bool
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: privacyMode && !isShowingDetails ? "DISK --" : compactText, accent: .purple)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .purple, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text(privacyMode ? "Hidden" : "Startup Disk")
                    .font(.system(size: 13, weight: .semibold))
                ProgressView(value: diskStatsService.snapshot.usage)
                    .frame(width: 180)
                Text(privacyMode ? "Privacy mode" : detailText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .dockPopoverPanel(width: 240)
        }
    }

    private var compactText: String {
        "DISK \(Int((diskStatsService.snapshot.usage * 100).rounded()))%"
    }

    private var detailText: String {
        "\(bytes(diskStatsService.snapshot.usedBytes)) / \(bytes(diskStatsService.snapshot.totalBytes))"
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }
}
