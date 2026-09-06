import Darwin
import Foundation

struct MonitoredProcess: Identifiable, Equatable {
    var id: Int32 { pid }

    let pid: Int32
    let uid: UInt32
    let name: String
    let cpuPercent: Double
    let residentMemoryBytes: UInt64

    var canTerminate: Bool {
        pid > 1
            && uid == getuid()
            && pid != getpid()
            && !Self.protectedProcessNames.contains(name)
            && !name.hasPrefix("kernel")
    }

    private static let protectedProcessNames: Set<String> = [
        "CloudDock",
        "WindowServer",
        "launchd",
        "loginwindow",
        "sysmond",
        "kernel_task"
    ]
}

enum ProcessSortMetric {
    case cpu
    case memory
}

final class ProcessMonitorService: ObservableObject {
    @Published private(set) var processes: [MonitoredProcess] = []

    func refresh() {
        guard let result = CommandRunner.run("/bin/ps", arguments: ["-axo", "pid=,uid=,pcpu=,rss=,comm="], timeout: 1.5) else {
            processes = []
            return
        }

        processes = parseProcesses(result.output)
    }

    func topProcesses(for metric: ProcessSortMetric, limit: Int = 3) -> [MonitoredProcess] {
        switch metric {
        case .cpu:
            return Array(processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(limit))
        case .memory:
            return Array(processes.sorted { $0.residentMemoryBytes > $1.residentMemoryBytes }.prefix(limit))
        }
    }

    @discardableResult
    func terminate(_ monitoredProcess: MonitoredProcess) -> Bool {
        guard monitoredProcess.canTerminate,
              let current = loadProcess(pid: monitoredProcess.pid),
              current.uid == monitoredProcess.uid,
              current.name == monitoredProcess.name,
              current.canTerminate else {
            return false
        }

        return kill(monitoredProcess.pid, SIGTERM) == 0
    }

    private func loadProcess(pid: Int32) -> MonitoredProcess? {
        guard let result = CommandRunner.run("/bin/ps", arguments: ["-p", "\(pid)", "-o", "pid=,uid=,pcpu=,rss=,comm="], timeout: 0.8) else {
            return nil
        }

        return result.output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap(parseProcessLine)
            .first
    }

    private func parseProcesses(_ output: String) -> [MonitoredProcess] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap(parseProcessLine)
    }

    private func parseProcessLine(_ line: Substring) -> MonitoredProcess? {
        let columns = line.split(maxSplits: 4, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard columns.count == 5,
              let pid = Int32(columns[0]),
              let uid = UInt32(columns[1]),
              let cpu = Double(columns[2]),
              let rssKilobytes = UInt64(columns[3]) else {
            return nil
        }

        let fullName = String(columns[4])
        let name = URL(fileURLWithPath: fullName).lastPathComponent

        return MonitoredProcess(
            pid: pid,
            uid: uid,
            name: name.isEmpty ? fullName : name,
            cpuPercent: cpu,
            residentMemoryBytes: rssKilobytes * 1024
        )
    }
}
