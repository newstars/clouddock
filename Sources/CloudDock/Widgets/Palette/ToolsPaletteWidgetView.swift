import AppKit
import SwiftUI

struct ToolsPaletteWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var launcherService: AppLauncherService
    @ObservedObject var clipboardService: ClipboardService
    @ObservedObject var quickNoteService: QuickNoteService
    let privacyMode: Bool
    @State private var isShowingTools = false

    var body: some View {
        Button {
            if !privacyMode {
                clipboardService.refresh()
            }
            isShowingTools.toggle()
        } label: {
            DockIconTile(accent: .purple, isActive: isShowingTools) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .help(descriptor.title)
        .popover(isPresented: $isShowingTools, arrowEdge: .bottom) {
            expandedContent
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(launcherService.apps) { app in
                    Button {
                        launcherService.open(app)
                    } label: {
                        Image(nsImage: launcherService.icon(for: app))
                            .resizable()
                            .frame(width: 24, height: 24)
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.borderless)
                    .help(app.name)
                    .draggable(app.id)
                    .dropDestination(for: String.self) { values, _ in
                        guard let draggedID = values.first else {
                            return false
                        }

                        launcherService.moveApp(draggedID, before: app.id)
                        return true
                    }
                }

                Button {
                    launcherService.chooseApplications()
                } label: {
                    Image(systemName: "plus.app")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.borderless)
                .help("Add Application")

            }

            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                Text(privacyMode ? "Clipboard hidden" : clipboardSummary)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }

            Text(privacyMode ? "Private content hidden" : noteOrClipboardText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .dockPopoverPanel(width: 260)
    }

    private var noteOrClipboardText: String {
        if !quickNoteService.text.isEmpty {
            return quickNoteService.text
        }

        if !clipboardService.snapshot.text.isEmpty {
            return clipboardService.snapshot.text
        }

        return "No note or clipboard text"
    }

    private var clipboardSummary: String {
        clipboardService.snapshot.text.isEmpty ? "No text copied" : clipboardService.snapshot.text
    }
}
