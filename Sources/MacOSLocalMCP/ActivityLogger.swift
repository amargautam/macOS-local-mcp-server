import Foundation

/// Logs tool call activity to a JSONL file for auditing and diagnostics.
/// Each line in the log file is a JSON object representing one tool call.
final class ActivityLogger {

    /// The default log file path.
    static let defaultLogPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp/activity.jsonl"
    }()

    /// The path to the log file.
    let logFilePath: String

    /// A serial queue for thread-safe writes.
    private let writeQueue = DispatchQueue(label: "com.amargautam.macos-local-mcp.activity-logger", qos: .utility)

    /// The ISO 8601 date formatter.
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Initialize with a specific log file path.
    init(logFilePath: String? = nil) {
        self.logFilePath = logFilePath ?? ActivityLogger.defaultLogPath
    }

    // MARK: - Public API

    /// Log a successful tool call.
    func logSuccess(tool: String, params: [String: Any], durationMs: Int, resultCount: Int) {
        let entry = LogEntry(
            ts: dateFormatter.string(from: Date()),
            tool: tool,
            params: params,
            status: "success",
            durationMs: durationMs,
            resultCount: resultCount,
            error: nil
        )
        writeEntry(entry)
    }

    /// Log a failed tool call.
    func logError(tool: String, params: [String: Any], durationMs: Int, error: String) {
        let entry = LogEntry(
            ts: dateFormatter.string(from: Date()),
            tool: tool,
            params: params,
            status: "error",
            durationMs: durationMs,
            resultCount: nil,
            error: error
        )
        writeEntry(entry)
    }

    /// Log a tool call that requires confirmation.
    func logConfirmationRequired(tool: String, params: [String: Any]) {
        let entry = LogEntry(
            ts: dateFormatter.string(from: Date()),
            tool: tool,
            params: params,
            status: "confirmation_required",
            durationMs: 0,
            resultCount: nil,
            error: nil
        )
        writeEntry(entry)
    }

    // MARK: - Private

    /// A single log entry.
    private struct LogEntry {
        let ts: String
        let tool: String
        let params: [String: Any]
        let status: String
        let durationMs: Int
        let resultCount: Int?
        let error: String?
    }

    /// Serialize a log entry to JSON and append it to the log file.
    private func writeEntry(_ entry: LogEntry) {
        writeQueue.sync {
            var dict: [String: Any] = [
                "ts": entry.ts,
                "tool": entry.tool,
                "params": simplifyParams(entry.params),
                "status": entry.status,
                "duration_ms": entry.durationMs,
            ]

            if let resultCount = entry.resultCount {
                dict["result_count"] = resultCount
            }

            if let error = entry.error {
                dict["error"] = error
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return
            }

            let line = jsonString + "\n"

            ensureFileExists()

            if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                fileHandle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        }
    }

    /// Ensure the log file and its parent directory exist.
    private func ensureFileExists() {
        let fm = FileManager.default
        let directory = (logFilePath as NSString).deletingLastPathComponent

        if !fm.fileExists(atPath: directory) {
            try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }

        if !fm.fileExists(atPath: logFilePath) {
            fm.createFile(atPath: logFilePath, contents: nil, attributes: [.posixPermissions: 0o600])
        }
    }

    /// Simplify params dictionary for JSON serialization (convert non-serializable values to strings).
    private func simplifyParams(_ params: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in params {
            if JSONSerialization.isValidJSONObject([key: value]) {
                result[key] = value
            } else {
                result[key] = String(describing: value)
            }
        }
        return result
    }
}
