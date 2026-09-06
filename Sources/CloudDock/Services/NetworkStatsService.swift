import Foundation

struct NetworkStatsSnapshot: Equatable {
    var downloadBytesPerSecond: UInt64
    var uploadBytesPerSecond: UInt64

    static let empty = NetworkStatsSnapshot(downloadBytesPerSecond: 0, uploadBytesPerSecond: 0)
}

final class NetworkStatsService: ObservableObject {
    @Published private(set) var snapshot = NetworkStatsSnapshot.empty

    private var previousTotal: (received: UInt64, sent: UInt64, date: Date)?

    func refresh() {
        guard let total = readInterfaceTotals() else {
            snapshot = .empty
            return
        }

        let now = Date()
        defer {
            previousTotal = (total.received, total.sent, now)
        }

        guard let previousTotal else {
            return
        }

        let interval = max(now.timeIntervalSince(previousTotal.date), 1)
        let receivedDelta = total.received > previousTotal.received ? total.received - previousTotal.received : 0
        let sentDelta = total.sent > previousTotal.sent ? total.sent - previousTotal.sent : 0

        snapshot = NetworkStatsSnapshot(
            downloadBytesPerSecond: UInt64(Double(receivedDelta) / interval),
            uploadBytesPerSecond: UInt64(Double(sentDelta) / interval)
        )
    }

    private func readInterfaceTotals() -> (received: UInt64, sent: UInt64)? {
        guard let result = CommandRunner.run("/usr/sbin/netstat", arguments: ["-ibn"], timeout: 1.5) else {
            return nil
        }

        return parseTotals(result.output)
    }

    private func parseTotals(_ output: String) -> (received: UInt64, sent: UInt64)? {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var seenInterfaces = Set<String>()

        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count >= 10 else {
                continue
            }

            let interface = String(columns[0])
            guard interface != "lo0", seenInterfaces.insert(interface).inserted else {
                continue
            }

            received += UInt64(columns[6]) ?? 0
            sent += UInt64(columns[9]) ?? 0
        }

        return (received, sent)
    }
}
