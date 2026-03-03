import Foundation

/// A single entry from the activity.jsonl log file.
/// Each entry represents one tool call made to the MCP server.
public struct ActivityEntry: Codable, Identifiable, Equatable {
    /// A stable identifier derived from the timestamp and tool name.
    public var id: String { "\(ts)-\(tool)" }

    /// ISO 8601 timestamp of the tool call.
    public let ts: String

    /// The name of the tool that was called.
    public let tool: String

    /// The status of the call: "success", "error", or "confirmation_required".
    public let status: String

    /// How long the call took in milliseconds.
    public let duration_ms: Int

    /// The number of results returned (nil for errors).
    public let result_count: Int?

    /// Error message if status is "error".
    public let error: String?

    public init(
        ts: String,
        tool: String,
        status: String,
        duration_ms: Int,
        result_count: Int? = nil,
        error: String? = nil
    ) {
        self.ts = ts
        self.tool = tool
        self.status = status
        self.duration_ms = duration_ms
        self.result_count = result_count
        self.error = error
    }
}

extension ActivityEntry {
    /// A Date value parsed from the ts field. Returns nil if parsing fails.
    public var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: ts) { return d }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: ts)
    }

    /// Whether this entry represents a successful call.
    public var isSuccess: Bool { status == "success" }

    /// Whether this entry represents an error.
    public var isError: Bool { status == "error" }
}
