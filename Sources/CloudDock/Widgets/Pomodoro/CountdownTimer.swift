import Foundation

struct CountdownTimer {
    private let duration: Int
    private var deadline: Date?
    private(set) var remainingSeconds: Int
    var isRunning: Bool { deadline != nil }

    init(duration: Int = 25 * 60) {
        self.duration = max(0, duration)
        remainingSeconds = max(0, duration)
    }

    mutating func toggle(at now: Date) {
        if isRunning {
            update(at: now)
            deadline = nil
        } else if remainingSeconds > 0 {
            deadline = now.addingTimeInterval(TimeInterval(remainingSeconds))
        }
    }

    mutating func update(at now: Date) {
        guard let deadline else { return }
        remainingSeconds = min(duration, max(0, Int(ceil(deadline.timeIntervalSince(now)))))
        if remainingSeconds == 0 { self.deadline = nil }
    }

    mutating func reset() {
        deadline = nil
        remainingSeconds = duration
    }
}
