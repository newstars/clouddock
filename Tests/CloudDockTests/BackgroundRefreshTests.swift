import Foundation

private actor OutputGate {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<String?, Never>?

    func load() async -> String? {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func finish(_ value: String?) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

enum BackgroundRefreshTests {
    @MainActor
    static func run() async {
        let batteryGate = OutputGate()
        let networkGate = OutputGate()
        let battery = BatteryStatusService(loadOutput: { await batteryGate.load() })
        let network = NetworkStatsService(loadOutput: { await networkGate.load() })
        battery.refresh()
        battery.refresh()
        network.refresh()
        network.refresh()
        precondition(battery.isRefreshing && network.isRefreshing)
        // Execution on MainActor reaches here before either delayed loader has returned.
        await eventually {
            let batteryCalls = await batteryGate.calls
            let networkCalls = await networkGate.calls
            return batteryCalls == 1 && networkCalls == 1
        }
        await batteryGate.finish("AC Power\n42%; charging;")
        await networkGate.finish(nil)
        await eventually { !battery.isRefreshing && !network.isRefreshing }
        precondition(battery.snapshot.percentage == 42)
        precondition(network.snapshot == .empty)
        battery.refresh()
        network.refresh()
        await eventually {
            let batteryCalls = await batteryGate.calls
            let networkCalls = await networkGate.calls
            return batteryCalls == 2 && networkCalls == 2
        }
        await batteryGate.finish(nil)
        await networkGate.finish("Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll\nen0 1500 <Link#1> abc 2 0 100 3 0 200 0")
        await eventually { !battery.isRefreshing && !network.isRefreshing }
        precondition(battery.snapshot == .unknown)
        print("PASS: battery/network nonblocking refresh, single flight, error recovery, retry")
    }

    @MainActor
    private static func eventually(_ condition: () async -> Bool) async {
        for _ in 0..<200 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Background refresh did not finish within test deadline")
    }
}
