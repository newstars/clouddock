import SwiftUI

struct DateWidgetView: View {
    let descriptor: DockWidgetDescriptor
    let privacyMode: Bool

    @State private var now = Date()
    @State private var isShowingDetails = false

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            DockCompactLabel(symbolName: descriptor.symbolName, text: privacyMode && !isShowingDetails ? "DATE" : compactDate, accent: .orange)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .orange, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(privacyMode ? "Hidden" : weekday)
                    .font(.system(size: 13, weight: .semibold))
                Text(privacyMode ? "Privacy mode" : longDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .dockPopoverPanel(width: 220)
        }
        .onReceive(timer) { value in
            now = value
        }
    }

    private var compactDate: String {
        now.formatted(.dateTime.month(.abbreviated).day())
    }

    private var weekday: String {
        now.formatted(.dateTime.weekday(.wide))
    }

    private var longDate: String {
        now.formatted(.dateTime.year().month(.wide).day())
    }
}
