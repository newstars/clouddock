import Foundation

enum MusicScriptTests {
    @MainActor
    static func run() async {
        let text = await MusicScriptExecutor.execute("return \"hello\"")
        precondition(text.text == "hello" && text.errorNumber == nil)
        let failure = await MusicScriptExecutor.execute("error \"test failure\" number -42")
        precondition(failure.errorNumber == -42)
        let invalid = await MusicScriptExecutor.execute("this is not valid AppleScript !!!")
        precondition(invalid.errorNumber != nil)
        async let first = MusicScriptExecutor.execute("return \"first\"")
        async let second = MusicScriptExecutor.execute("return \"second\"")
        let results = await (first, second)
        precondition(results.0.text == "first" && results.1.text == "second")
        print("PASS: script value transfer, failure, invalid syntax, concurrent submissions")
    }
}
