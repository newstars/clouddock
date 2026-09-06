import SwiftUI

enum SystemMetricKind {
    case cpu
    case memory

    var processSortMetric: ProcessSortMetric {
        switch self {
        case .cpu: .cpu
        case .memory: .memory
        }
    }
}

struct SystemMetricWidgetView: View {
    let descriptor: DockWidgetDescriptor
    let metric: SystemMetricKind
    @ObservedObject var metricsService: SystemMetricsService
    @ObservedObject var processMonitorService: ProcessMonitorService
    let privacyMode: Bool
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails.toggle()
        } label: {
            compactContent
                .dockTile(width: DockLayoutCalculator.compactWidth(for: descriptor.id), accent: accent, isActive: isShowingDetails)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
            expandedContent
        }
    }

    private var compactContent: some View {
        HStack(spacing: 8) {
            DockCompactLabel(symbolName: descriptor.symbolName, text: privacyMode && !isShowingDetails ? privateCompactText : compactText, accent: accent)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detailTitle)
                        .font(.system(size: 11, weight: .semibold))
                    Text(privacyMode ? "Process details hidden" : detailText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                ProgressView(value: progressValue)
                    .frame(width: 82)
            }

            if privacyMode {
                Text("Privacy mode")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                if topProcesses.isEmpty {
                    Text("No processes available")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(topProcesses) { process in
                                ProcessRowView(
                                    process: process,
                                    metric: metric,
                                    terminate: {
                                        _ = processMonitorService.terminate(process)
                                        processMonitorService.refresh()
                                    }
                                )
                                .frame(height: 44)
                                Divider()
                            }
                        }
                        .padding(.trailing, 12)
                    }
                    .frame(height: CGFloat(min(topProcesses.count, 7)) * 45)
                }
            }
        }
        .dockPopoverPanel(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var topProcesses: [MonitoredProcess] {
        processMonitorService.topProcesses(for: metric.processSortMetric, limit: processMonitorService.processes.count)
    }

    private var compactText: String {
        switch metric {
        case .cpu:
            "CPU \(percent(metricsService.snapshot.cpuUsage))"
        case .memory:
            "MEM \(percent(metricsService.snapshot.memoryUsage))"
        }
    }

    private var accent: Color {
        switch metric {
        case .cpu: .cyan
        case .memory: .mint
        }
    }

    private var privateCompactText: String {
        switch metric {
        case .cpu: "CPU --"
        case .memory: "MEM --"
        }
    }

    private var detailTitle: String {
        switch metric {
        case .cpu: "Top CPU"
        case .memory: "Top Memory"
        }
    }

    private var detailText: String {
        switch metric {
        case .cpu:
            "\(percent(metricsService.snapshot.cpuUsage)) active"
        case .memory:
            "\(bytes(metricsService.snapshot.usedMemoryBytes)) / \(bytes(metricsService.snapshot.totalMemoryBytes))"
        }
    }

    private var progressValue: Double {
        switch metric {
        case .cpu: metricsService.snapshot.cpuUsage
        case .memory: metricsService.snapshot.memoryUsage
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }
}
