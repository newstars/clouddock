import SwiftUI

struct PomodoroWidgetView: View {
    let descriptor: DockWidgetDescriptor

    @State private var remainingSeconds = 25 * 60
    @State private var isRunning = false
    @State private var isShowingControls = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingControls.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: timeText, accent: .red)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .red, isActive: isRunning || isShowingControls)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingControls, arrowEdge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    isRunning.toggle()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)

                Text(timeText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Button {
                    isRunning = false
                    remainingSeconds = 25 * 60
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }
            .dockPopoverPanel(width: 170)
        }
        .onReceive(timer) { _ in
            guard isRunning else {
                return
            }

            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                isRunning = false
            }
        }
    }

    private var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
