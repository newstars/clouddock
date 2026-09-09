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
        ClipboardTests.run()
        CommandRunnerTests.run()
        let start = Date(timeIntervalSince1970: 1000)
        var countdown = CountdownTimer(duration: 60)
        countdown.toggle(at: start)
        countdown.update(at: start.addingTimeInterval(10))
        precondition(countdown.remainingSeconds == 50)
        countdown.toggle(at: start.addingTimeInterval(15))
        precondition(countdown.remainingSeconds == 45 && !countdown.isRunning)
        countdown.update(at: start.addingTimeInterval(100))
        precondition(countdown.remainingSeconds == 45)
        countdown.toggle(at: start.addingTimeInterval(100))
        countdown.update(at: start.addingTimeInterval(200))
        precondition(countdown.remainingSeconds == 0 && !countdown.isRunning)
        countdown.reset()
        precondition(countdown.remainingSeconds == 60)
        print("PASS: countdown pause/resume, delayed ticks, elapsed deadline, reset")
    }
}
