import Darwin
import Foundation

struct SystemSnapshot: Equatable {
    var cpuUsage: Double
    var usedMemoryBytes: UInt64
    var totalMemoryBytes: UInt64

    var memoryUsage: Double {
        guard totalMemoryBytes > 0 else {
            return 0
        }
        return Double(usedMemoryBytes) / Double(totalMemoryBytes)
    }
}

final class SystemMetricsService: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot(cpuUsage: 0, usedMemoryBytes: 0, totalMemoryBytes: 0)

    private var previousCPUInfo: host_cpu_load_info?

    func refresh() {
        snapshot = SystemSnapshot(
            cpuUsage: readCPUUsage(),
            usedMemoryBytes: readUsedMemoryBytes(),
            totalMemoryBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    private func readCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return snapshot.cpuUsage
        }

        defer {
            previousCPUInfo = cpuInfo
        }

        guard let previousCPUInfo else {
            return 0
        }

        // Kernel counters wrap on long-running systems.
        let user = Double(cpuInfo.cpu_ticks.0 &- previousCPUInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1 &- previousCPUInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2 &- previousCPUInfo.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3 &- previousCPUInfo.cpu_ticks.3)
        let total = user + system + idle + nice

        guard total > 0 else {
            return snapshot.cpuUsage
        }

        return min(max((total - idle) / total, 0), 1)
    }

    private func readUsedMemoryBytes() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return snapshot.usedMemoryBytes
        }

        var rawPageSize = vm_size_t()
        host_page_size(mach_host_self(), &rawPageSize)
        let pageSize = UInt64(rawPageSize)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return active + wired + compressed
    }
}
