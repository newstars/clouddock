import Foundation

@main
struct RefreshPolicyTests {
    static func main() {
        let hidden = DockRefreshPolicy(enabled: Set(DockWidgetID.allCases), isVisible: false, privacyMode: false)
        for widget in DockWidgetID.allCases {
            precondition(!hidden.refreshes(widget, tick: 0), "Hidden dock polled \(widget)")
        }
        precondition(hidden.capturesClipboard)
        let empty = DockRefreshPolicy(enabled: [], isVisible: true, privacyMode: false)
        precondition(!empty.capturesClipboard)
        precondition(!empty.refreshes(.cpu, tick: 0))
        let privatePolicy = DockRefreshPolicy(enabled: [.clipboard], isVisible: false, privacyMode: true)
        precondition(!privatePolicy.capturesClipboard)
        let visible = DockRefreshPolicy(enabled: [.cpu, .gitStatus, .disk, .battery], isVisible: true, privacyMode: false)
        precondition(visible.refreshes(.cpu, tick: 1))
        precondition(!visible.refreshes(.gitStatus, tick: 1))
        precondition(visible.refreshes(.gitStatus, tick: 8))
        precondition(visible.refreshes(.disk, tick: 30))
        precondition(visible.refreshes(.battery, tick: 0))

        let battery = BatteryStatusService()
        precondition(!battery.parse("Battery Power\n50%; discharging;").isCharging)
        precondition(!battery.parse("AC Power\n50%; not charging;").isCharging)
        precondition(!battery.parse("AC Power\n100%; charged;").isCharging)
        let charging = battery.parse("AC Power\n50%; charging;")
        precondition(charging.isCharging && charging.isPluggedIn && charging.percentage == 50)
        print("PASS: hidden/disabled polling, clipboard privacy, refresh intervals, battery states")
    }
}
