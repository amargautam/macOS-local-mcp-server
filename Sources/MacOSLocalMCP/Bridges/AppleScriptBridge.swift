import Foundation

/// Abstraction for executing AppleScript/osascript so the real execution
/// can be swapped out for a test double that just records the generated script
/// without running it.
protocol ScriptExecuting {
    /// Execute an AppleScript source string and return stdout.
    /// - Parameter source: The AppleScript source to execute.
    /// - Returns: Trimmed stdout string from the script.
    /// - Throws: `AppleScriptError` if the process exits with a non-zero status
    ///   or writes to stderr.
    func executeScript(_ source: String) throws -> String
}

/// Errors produced by `AppleScriptBridge`.
enum AppleScriptError: Error, Equatable {
    /// The script process returned a non-zero exit code.
    /// - Parameter message: The stderr output or a generic message.
    case executionFailed(String)
    /// The script source could not be compiled.
    case compilationFailed(String)
    /// The script returned no usable result.
    case noResult
    /// The script output could not be parsed as expected.
    case parseError(String)
}

extension AppleScriptError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "AppleScript execution failed: \(message)"
        case .compilationFailed(let message):
            return "AppleScript compilation failed: \(message)"
        case .noResult:
            return "AppleScript returned no result"
        case .parseError(let message):
            return "AppleScript parse error: \(message)"
        }
    }
}

/// Real implementation of `ScriptExecuting` that runs scripts via `osascript -e`.
final class AppleScriptBridge: ScriptExecuting {

    func executeScript(_ source: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            let message = stderr.isEmpty ? "Exit code \(process.terminationStatus)" : stderr
            throw AppleScriptError.executionFailed(message)
        }

        if !stderr.isEmpty {
            throw AppleScriptError.executionFailed(stderr)
        }

        return stdout
    }
}
