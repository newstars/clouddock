import Foundation
import Combine

struct BatteryStatusSnapshot: Equatable {
    var percentage: Int?
    var isCharging: Bool
    var isPluggedIn: Bool
    var detail: String

    static let unknown = BatteryStatusSnapshot(
        percentage: nil,
        isCharging: false,
        isPluggedIn: false,
        detail: "Power"
    )

    var compactText: String {
        if let percentage {
            return "BAT \(percentage)%"
        }
        return isPluggedIn ? "AC Power" : "Battery --"
    }
}

@MainActor
final class BatteryStatusService: ObservableObject {
    @Published private(set) var snapshot = BatteryStatusSnapshot.unknown
    private(set) var isRefreshing = false
    private let loadOutput: @Sendable () async -> String?

    init(loadOutput: @escaping @Sendable () async -> String? = {
        await Task.detached(priority: .utility) {
            CommandRunner.run("/usr/bin/pmset", arguments: ["-g", "batt"], timeout: 1.5)?.output
        }.value
    }) {
        self.loadOutput = loadOutput
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let load = loadOutput
        Task { [weak self] in
            let output = await load()
            guard let self else { return }
            self.snapshot = output.map(self.parse) ?? .unknown
            self.isRefreshing = false
        }
    }

    func parse(_ output: String) -> BatteryStatusSnapshot {
        let isPluggedIn = output.localizedCaseInsensitiveContains("AC Power")
        let isCharging = output.localizedCaseInsensitiveContains("charging")
            && !output.localizedCaseInsensitiveContains("not charging")
            && !output.localizedCaseInsensitiveContains("discharging")

        let percentage = output
            .split(whereSeparator: \.isWhitespace)
            .first { $0.hasSuffix("%;") || $0.hasSuffix("%") }
            .flatMap { token -> Int? in
                let digits = token.prefix { $0.isNumber }
                return Int(digits)
            }

        let detail: String
        if output.localizedCaseInsensitiveContains("no batteries") {
            detail = "No battery"
        } else if isCharging {
            detail = "Charging"
        } else if isPluggedIn {
            detail = "Plugged in"
        } else {
            detail = "On battery"
        }

        return BatteryStatusSnapshot(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            detail: detail
        )
    }
}
