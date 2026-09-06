import SwiftUI

struct QuickNoteWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var quickNoteService: QuickNoteService
    let privacyMode: Bool
    @State private var isShowingNote = false

    var body: some View {
        Button {
            isShowingNote.toggle()
        } label: {
            DockIconTile(accent: .yellow, isActive: isShowingNote) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .help(descriptor.title)
        .popover(isPresented: $isShowingNote, arrowEdge: .bottom) {
            notePopover
        }
    }

    private var notePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 13, weight: .semibold))

            TextEditor(text: Binding(
                get: { privacyMode ? "" : quickNoteService.text },
                set: { quickNoteService.setText($0) }
            ))
            .font(.system(size: 11))
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(width: 240, height: 112)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(privacyMode)
        }
        .dockPopoverPanel(width: 260)
    }

    private var iconName: String {
        quickNoteService.text.isEmpty || privacyMode ? descriptor.symbolName : "note.text.badge.plus"
    }
}
