import SwiftUI

struct ClipboardWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var clipboardService: ClipboardService
    let privacyMode: Bool

    @State private var isShowingHistory = false

    var body: some View {
        Button {
            if !privacyMode {
                clipboardService.refresh()
            }
            isShowingHistory.toggle()
        } label: {
            DockIconTile(accent: .gray, isActive: isShowingHistory) {
                Image(systemName: descriptor.symbolName)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .help(descriptor.title)
        .popover(isPresented: $isShowingHistory, arrowEdge: .bottom) {
            historyPopover
        }
    }

    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { clipboardService.clearHistory() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear clipboard history")
                .accessibilityLabel("Clear clipboard history")
                .disabled(clipboardService.history.isEmpty)
            }

            if privacyMode {
                Text("Privacy mode")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if clipboardService.history.isEmpty {
                Text("No recent text")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(clipboardService.history) { item in
                    Button {
                        clipboardService.copy(item)
                        isShowingHistory = false
                    } label: {
                        Text(item.preview)
                            .font(.system(size: 11))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .dockPopoverPanel(width: 260)
    }
}
