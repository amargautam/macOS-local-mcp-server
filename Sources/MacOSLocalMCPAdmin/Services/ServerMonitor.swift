import Foundation

// MARK: - Protocol

/// Monitors the macOS Local MCP server availability.
///
/// The server uses spawn-on-demand architecture — MCP clients launch a fresh
/// process per session. Monitoring checks whether the binary is installed
/// and optionally whether a process is currently active.
public protocol ServerMonitoring {
    /// Whether the server binary is installed at the expected path.
    func isConfigured() -> Bool
    /// Whether a server process is currently running (caught mid-request).
    func isActive() -> Bool
    /// The PID of a currently running server process, or nil.
    func pid() -> Int?
    /// The date of the most recent activity (from heartbeat or activity log).
    func lastActivityDate() -> Date?
}

// MARK: - Concrete Implementation

/// Checks whether the server binary is installed and optionally detects
/// a running process via PID file or process scanning.
public final class ServerMonitor: ServerMonitoring {

    // MARK: - Configuration

    /// The expected path to the server binary.
    private let binaryPath: String

    /// The path to the PID file written by a running server.
    private let pidFilePath: String

    /// The path to the heartbeat file written by a running server.
    private let heartbeatFilePath: String

    /// The process name to search for via pgrep when the PID file is missing.
    /// Set to nil to disable process scanning (useful in tests).
    private let processName: String?

    // MARK: - Init

    public convenience init() {
        let base = ServerMonitor.defaultDataDirectory
        self.init(
            binaryPath: ServerMonitor.defaultBinaryPath,
            pidFilePath: "\(base)/server.pid",
            heartbeatFilePath: "\(base)/heartbeat"
        )
    }

    public init(
        binaryPath: String,
        pidFilePath: String,
        heartbeatFilePath: String,
        processName: String? = "macos-local-mcp"
    ) {
        self.binaryPath = binaryPath
        self.pidFilePath = pidFilePath
        self.heartbeatFilePath = heartbeatFilePath
        self.processName = processName
    }

    // MARK: - ServerMonitoring

    public func isConfigured() -> Bool {
        return FileManager.default.isExecutableFile(atPath: binaryPath)
    }

    public func isActive() -> Bool {
        // Try PID file first
        if let pid = pidFromFile(), processExists(pid: pid) {
            return true
        }
        // Fallback: scan for running process by name
        if let pid = findProcessByName(), processExists(pid: pid) {
            return true
        }
        return false
    }

    public func pid() -> Int? {
        if let pid = pidFromFile(), processExists(pid: pid) {
            return pid
        }
        return findProcessByName()
    }

    public func lastActivityDate() -> Date? {
        return readHeartbeatDate()
    }

    // MARK: - Private helpers

    private func pidFromFile() -> Int? {
        guard let raw = try? String(contentsOfFile: pidFilePath, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }

    /// Find a running macOS Local MCP process via pgrep (fallback when PID file missing).
    private func findProcessByName() -> Int? {
        guard let name = processName else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let pids = output.split(separator: "\n").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return pids.first
    }

    private func readHeartbeatDate() -> Date? {
        guard let raw = try? String(contentsOfFile: heartbeatFilePath, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }

    /// Sends signal 0 to the PID to check whether the process exists.
    private func processExists(pid: Int) -> Bool {
        return kill(Int32(pid), 0) == 0
    }

    // MARK: - Static helpers

    static let defaultDataDirectory: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp"
    }()

    static let defaultBinaryPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/bin/macos-local-mcp"
    }()
}
