import Foundation

/// Protocol abstracting shell command execution for testability.
protocol ShellCommandExecuting {
    /// Execute a shell command and return its stdout output as a string.
    /// - Parameters:
    ///   - command: Absolute path to the executable (e.g. "/usr/bin/mdfind").
    ///   - arguments: Arguments to pass to the command.
    /// - Returns: The combined stdout output of the command.
    /// - Throws: `ShellError` if the process could not be launched or returned a non-zero exit code.
    func execute(command: String, arguments: [String]) throws -> String
}

/// Errors thrown by the shell bridge.
enum ShellError: Error, LocalizedError {
    case launchFailed(String)
    case nonZeroExit(Int32, String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg):
            return "Shell launch failed: \(msg)"
        case .nonZeroExit(let code, let stderr):
            return "Shell command exited with code \(code): \(stderr)"
        }
    }
}

/// Real implementation of `ShellCommandExecuting` using `Process`.
struct ProcessShellExecutor: ShellCommandExecuting {
    func execute(command: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: stdoutData, encoding: .utf8) ?? ""
        let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            throw ShellError.nonZeroExit(exitCode, errorOutput)
        }

        return output
    }
}
