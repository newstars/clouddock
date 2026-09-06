import Foundation

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

final class BatteryStatusService: ObservableObject {
    @Published private(set) var snapshot = BatteryStatusSnapshot.unknown

    func refresh() {
        guard let result = CommandRunner.run("/usr/bin/pmset", arguments: ["-g", "batt"], timeout: 1.5) else {
            snapshot = .unknown
            return
        }

        snapshot = parse(result.output)
    }

    private func parse(_ output: String) -> BatteryStatusSnapshot {
        let isPluggedIn = output.localizedCaseInsensitiveContains("AC Power")
        let isCharging = output.localizedCaseInsensitiveContains("charging")
            && !output.localizedCaseInsensitiveContains("not charging")

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
