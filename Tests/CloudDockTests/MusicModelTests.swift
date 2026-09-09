import Foundation

private actor ScriptGate {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<MusicScriptResult, Never>?
    func execute(_ source: String) async -> MusicScriptResult {
        calls += 1
        precondition(continuation == nil, "Music operations overlapped")
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(text: String = "", error: Int? = nil) {
        let waiting = continuation
        continuation = nil
        waiting?.resume(returning: MusicScriptResult(text: text, data: Data(), errorNumber: error, errorMessage: nil))
    }
}

enum MusicModelTests {
    @MainActor
    static func run() async {
        let gate = ScriptGate()
        let model = MusicWidgetModel(execute: { await gate.execute($0) }, running: { true }, usageDescription: "test")
        model.refresh()
        model.refresh()
        model.togglePlayPause()
        precondition(model.isBusy)
        await eventually { await gate.calls == 1 }
        // MainActor is available while a script is deliberately held pending.
        await gate.finish(text: "stopped|||||||||||||||0|||0")
        await eventually { !model.isBusy }
        model.togglePlayPause()
        model.togglePlayPause()
        await eventually { await gate.calls == 2 }
        await gate.finish(error: -1743)
        await eventually { !model.isBusy }
        precondition(model.error?.contains("Automation") == true)
        model.refresh()
        precondition(!model.isBusy, "Timer must not repeatedly request denied access")
        model.refresh(clearError: true)
        await eventually { await gate.calls == 3 }
        await gate.finish(text: "playing|||Song|||Artist|||Album|||100|||25")
        await eventually { await gate.calls == 4 }
        precondition(model.isBusy && model.trackTitle == "Song")
        await gate.finish(error: -1728)
        await eventually { !model.isBusy }
        precondition(model.error == nil && model.artwork == nil && model.progress == 0.25)
        model.togglePlayPause()
        await eventually { await gate.calls == 5 }
        await gate.finish(text: "no-track")
        await eventually { !model.isBusy }
        precondition(model.error?.contains("Choose a song") == true)
        await verifyLifecycle()
        print("PASS: music single-flight, MainActor responsiveness, denied access/retry, optional artwork, empty queue")
    }

    @MainActor
    private static func verifyLifecycle() async {
        let gate = ScriptGate()
        var running = true
        let model = MusicWidgetModel(execute: { await gate.execute($0) }, running: { running }, usageDescription: "test")
        model.refresh()
        await eventually { await gate.calls == 1 }
        running = false
        model.musicLifecycleChanged()
        await gate.finish(text: "playing|||Old song|||Artist|||Album|||100|||25")
        await eventually { !model.isBusy }
        precondition(model.trackTitle == "Music" && model.state == .stopped)
        model.refresh()
        await eventually { !model.isBusy }
        let callsWhileStopped = await gate.calls
        precondition(callsWhileStopped == 1, "Stopped Music must not receive status scripts")
        running = true
        model.musicLifecycleChanged()
        model.refresh()
        await eventually { await gate.calls == 2 }
        await gate.finish(text: "playing|||New song|||Artist|||Album|||100|||25")
        await eventually { await gate.calls == 3 }
        model.musicLifecycleChanged()
        await gate.finish()
        await eventually { !model.isBusy }
        precondition(model.trackTitle == "Music" && model.artwork == nil)
        model.refresh()
        await eventually { await gate.calls == 4 }
        await gate.finish(text: "clouddock:not-running")
        await eventually { !model.isBusy }
        precondition(model.state == .stopped && model.error == nil)
        print("PASS: music quit/restart stale status and artwork, stopped polling, script lifecycle guard")
    }

    @MainActor
    private static func eventually(_ condition: () async -> Bool) async {
        for _ in 0..<200 {
            if await condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Music model test timed out")
    }
}
