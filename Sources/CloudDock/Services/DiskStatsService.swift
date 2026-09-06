import Foundation

struct DiskStatsSnapshot: Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64

    static let empty = DiskStatsSnapshot(usedBytes: 0, totalBytes: 0)

    var usage: Double {
        guard totalBytes > 0 else {
            return 0
        }
        return Double(usedBytes) / Double(totalBytes)
    }
}

final class DiskStatsService: ObservableObject {
    @Published private(set) var snapshot = DiskStatsSnapshot.empty

    func refresh() {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            snapshot = DiskStatsSnapshot(usedBytes: total > available ? total - available : 0, totalBytes: total)
        } catch {
            snapshot = .empty
        }
    }
}
