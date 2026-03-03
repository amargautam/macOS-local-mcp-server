import Foundation

// MARK: - Protocol

/// Provides access to the macOS Local MCP activity log.
public protocol ActivityFeedProviding {
    /// Load the most recent entries from the log, newest first.
    /// - Parameter limit: Maximum number of entries to return.
    func loadEntries(limit: Int) -> [ActivityEntry]

    /// The total number of valid (parseable) entries in the log.
    func entriesCount() -> Int
}

// MARK: - Concrete Implementation

/// Reads `activity.jsonl` from the macOS Local MCP data directory.
/// Each line in the file is a JSON object representing one tool call.
public final class ActivityFeedService: ActivityFeedProviding {

    private let logFilePath: String

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    // MARK: - Init

    public convenience init() {
        let base = ServerMonitor.defaultDataDirectory
        self.init(logFilePath: "\(base)/activity.jsonl")
    }

    public init(logFilePath: String) {
        self.logFilePath = logFilePath
    }

    // MARK: - ActivityFeedProviding

    public func loadEntries(limit: Int) -> [ActivityEntry] {
        let all = parseAllLines()
        // Return newest first, capped at limit.
        let reversed = Array(all.reversed())
        if limit >= reversed.count { return reversed }
        return Array(reversed.prefix(limit))
    }

    public func entriesCount() -> Int {
        parseAllLines().count
    }

    // MARK: - Private

    /// Read the file line-by-line and parse each as an ActivityEntry,
    /// silently dropping lines that fail to parse.
    private func parseAllLines() -> [ActivityEntry] {
        guard let content = try? String(contentsOfFile: logFilePath, encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { line -> ActivityEntry? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(ActivityEntry.self, from: data)
            }
    }
}
