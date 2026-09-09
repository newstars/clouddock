import Darwin
import Foundation

struct CommandResult {
    var status: Int32
    var output: String
}

enum CommandRunner {
    static func run(_ executablePath: String, arguments: [String],
                    timeout: TimeInterval = 1.5, maximumOutputBytes: Int = 4 * 1024 * 1024) -> CommandResult? {
        guard timeout.isFinite, timeout > 0, maximumOutputBytes > 0 else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        let handles = [output.fileHandleForReading, errors.fileHandleForReading]
        for handle in handles {
            let fd = handle.fileDescriptor
            let flags = fcntl(fd, F_GETFL)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else { return nil }
        }
        defer { handles.forEach { try? $0.close() } }
        do { try process.run() } catch { return nil }
        // Close parent writers so EOF is observable after the child closes its copies.
        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        defer {
            if process.isRunning {
                process.terminate()
                if completion.wait(timeout: .now() + 0.25) == .timedOut, process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                    _ = completion.wait(timeout: .now() + 0.25)
                }
            }
        }

        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var data = Data()
        var closed = [false, false]
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            for index in handles.indices where !closed[index] {
                // Bound each drain pass so continuous output cannot starve the deadline check.
                for _ in 0..<16 {
                    let count = buffer.withUnsafeMutableBytes { bytes in
                        read(handles[index].fileDescriptor, bytes.baseAddress, bytes.count)
                    }
                    if count > 0 {
                        if index == 0 {
                            guard count <= maximumOutputBytes - data.count else { return nil }
                            data.append(contentsOf: buffer.prefix(count))
                        }
                    } else if count == 0 {
                        closed[index] = true
                        break
                    } else if errno == EAGAIN || errno == EWOULDBLOCK {
                        break
                    } else if errno != EINTR {
                        return nil
                    }
                }
            }
            if closed.allSatisfy({ $0 }) && !process.isRunning {
                guard process.terminationStatus == 0 else { return nil }
                return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
            }
            // No read-to-EOF calls: a descendant retaining a pipe cannot outlive the deadline.
            var descriptors = handles.indices.map {
                pollfd(fd: closed[$0] ? -1 : handles[$0].fileDescriptor, events: Int16(POLLIN), revents: 0)
            }
            _ = poll(&descriptors, nfds_t(descriptors.count), 10)
        }
    }
}
