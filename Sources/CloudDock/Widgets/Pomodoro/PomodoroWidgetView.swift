import SwiftUI

struct PomodoroWidgetView: View {
    let descriptor: DockWidgetDescriptor

    @State private var countdown = CountdownTimer()
    @State private var isShowingControls = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingControls.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: timeText, accent: .red)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .red, isActive: countdown.isRunning || isShowingControls)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingControls, arrowEdge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    countdown.toggle(at: .now)
                } label: {
                    Image(systemName: countdown.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)

                Text(timeText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Button {
                    countdown.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }
            .dockPopoverPanel(width: 170)
        }
        .onReceive(timer) { _ in
            countdown.update(at: .now)
        }
    }

    private var timeText: String {
        let minutes = countdown.remainingSeconds / 60
        let seconds = countdown.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
