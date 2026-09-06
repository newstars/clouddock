import SwiftUI

struct ProcessRowView: View {
    let process: MonitoredProcess
    let metric: SystemMetricKind
    let terminate: () -> Void
    @State private var isConfirmingTerminate = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .help(process.name)
                Text(metricText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 4)

            Button {
                isConfirmingTerminate = true
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(!process.canTerminate)
            .help("Terminate process")
            .confirmationDialog(
                "Terminate \(process.name)?",
                isPresented: $isConfirmingTerminate
            ) {
                Button("Terminate", role: .destructive) {
                    terminate()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("CloudDock will send SIGTERM to pid \(process.pid). Unsaved work in that process may be lost.")
            }
        }
    }

    private var metricText: String {
        switch metric {
        case .cpu:
            return "pid \(process.pid)  \(String(format: "%.1f", process.cpuPercent))%"
        case .memory:
            return "pid \(process.pid)  \(ByteCountFormatter.string(fromByteCount: Int64(process.residentMemoryBytes), countStyle: .memory))"
        }
    }
}
