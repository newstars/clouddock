import Darwin
import Foundation

struct CommandResult {
    var status: Int32
    var output: String
}

enum CommandRunner {
    static func run(_ executablePath: String, arguments: [String], timeout: TimeInterval = 1.5) -> CommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let semaphore = DispatchSemaphore(value: 0)
        let outputBuffer = LockedDataBuffer()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            outputBuffer.append(data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            // Drain stderr while the child runs so a noisy command cannot block on a full pipe.
            _ = handle.availableData
        }
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if semaphore.wait(timeout: .now() + 0.25) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = semaphore.wait(timeout: .now() + 0.25)
            }
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
        outputBuffer.append(remainingOutput)
        let data = outputBuffer.data()

        guard process.terminationStatus == 0 else {
            return nil
        }

        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else {
            return
        }

        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        let data = storage
        lock.unlock()
        return data
    }
}
