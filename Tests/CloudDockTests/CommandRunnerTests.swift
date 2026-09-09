import Foundation

enum CommandRunnerTests {
    static func run() {
        precondition(CommandRunner.run("/usr/bin/printf", arguments: ["hello"])?.output == "hello")
        precondition(CommandRunner.run("/usr/bin/false", arguments: []) == nil)
        precondition(CommandRunner.run("/not/a/command", arguments: []) == nil)
        precondition(CommandRunner.run("/usr/bin/printf", arguments: ["12345"], maximumOutputBytes: 4) == nil)
        precondition(CommandRunner.run("/usr/bin/printf", arguments: ["1234"], maximumOutputBytes: 4)?.output == "1234")
        let start = ProcessInfo.processInfo.systemUptime
        precondition(CommandRunner.run("/bin/sleep", arguments: ["5"], timeout: 0.1) == nil)
        precondition(ProcessInfo.processInfo.systemUptime - start < 2)
        let result = CommandRunner.run("/bin/sh", arguments: ["-c", "i=0; while [ $i -lt 5000 ]; do printf 'noise\\n' >&2; i=$((i+1)); done; printf done"], timeout: 3)
        precondition(result?.output == "done", "stderr must drain without blocking stdout")
        print("PASS: command success/failure, missing executable, output limit, timeout, stderr drainage")
    }
}
