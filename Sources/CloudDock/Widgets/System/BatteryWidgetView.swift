import SwiftUI

struct BatteryWidgetView: View {
    let descriptor: DockWidgetDescriptor
    @ObservedObject var batteryStatusService: BatteryStatusService
    let privacyMode: Bool
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            DockCompactLabel(symbolName: symbolName, text: privacyMode && !isShowingDetails ? "BAT --" : batteryStatusService.snapshot.compactText, accent: .green)
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: .green, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(privacyMode ? "Hidden" : batteryStatusService.snapshot.detail)
                    .font(.system(size: 13, weight: .semibold))
                Text(privacyMode ? "Privacy mode" : batteryStatusService.snapshot.compactText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .dockPopoverPanel(width: 200)
        }
    }

    private var symbolName: String {
        if batteryStatusService.snapshot.isCharging {
            return "battery.100percent.bolt"
        }

        guard let percentage = batteryStatusService.snapshot.percentage else {
            return descriptor.symbolName
        }

        switch percentage {
        case 0..<25: return "battery.25percent"
        case 25..<75: return "battery.50percent"
        default: return "battery.100percent"
        }
    }
}
