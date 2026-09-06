import SwiftUI

struct ClockWidgetView: View {
    let descriptor: DockWidgetDescriptor
    let privacyMode: Bool

    @State private var now = Date()
    @State private var isShowingDetails = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            VStack(spacing: 1) {
                Text(privacyMode ? "--:--" : compactTime)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(privacyMode ? "---" : fullDate)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .gray, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(privacyMode ? "Clock" : "\(compactTime), \(fullDate)")
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(privacyMode ? "Privacy mode" : fullDate)
                    .font(.system(size: 13, weight: .semibold))
                Text(privacyMode ? "Time details hidden" : timeZone)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .dockPopoverPanel(width: 220)
        }
        .onReceive(timer) { value in
            now = value
        }
    }

    private var compactTime: String {
        now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private var fullDate: String {
        now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var timeZone: String {
        TimeZone.current.identifier
    }
}
