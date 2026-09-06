import AppKit
import SwiftUI

struct DockDragHandle: View {
    var body: some View {
        ZStack {
            Image(systemName: "grip.vertical")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            WindowDragHandleRepresentable()
        }
        .frame(width: DockLayoutCalculator.dockDragHandleWidth, height: DockLayoutCalculator.compactWidgetHeight)
        .contentShape(Rectangle())
        .help("Move CloudDock")
    }
}

private struct WindowDragHandleRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragHandleView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowDragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
