import Foundation

/// Writes a heartbeat timestamp to `~/.macos-local-mcp/heartbeat` every 30 seconds.
/// Used by the admin app or external monitors to verify the server is alive.
final class HeartbeatManager {

    /// The default heartbeat file path.
    static let defaultHeartbeatPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp/heartbeat"
    }()

    /// The path to the heartbeat file.
    let heartbeatFilePath: String

    /// The heartbeat interval in seconds.
    let intervalSeconds: TimeInterval

    /// The timer that drives heartbeat writes.
    private var timer: DispatchSourceTimer?

    /// The queue on which the timer fires.
    private let queue = DispatchQueue(label: "com.amargautam.macos-local-mcp.heartbeat", qos: .utility)

    /// Whether the heartbeat manager is currently running.
    private(set) var isRunning: Bool = false

    /// The ISO 8601 date formatter.
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Initialize with optional custom path and interval.
    init(heartbeatFilePath: String? = nil, intervalSeconds: TimeInterval = 30) {
        self.heartbeatFilePath = heartbeatFilePath ?? HeartbeatManager.defaultHeartbeatPath
        self.intervalSeconds = intervalSeconds
    }

    // MARK: - Public API

    /// Start the heartbeat timer. Writes immediately, then every intervalSeconds.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Write immediately on start
        writeHeartbeat()

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + intervalSeconds, repeating: intervalSeconds)
        source.setEventHandler { [weak self] in
            self?.writeHeartbeat()
        }
        source.resume()
        timer = source
    }

    /// Stop the heartbeat timer.
    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    // MARK: - Private

    /// Write the current timestamp to the heartbeat file.
    private func writeHeartbeat() {
        let timestamp = dateFormatter.string(from: Date())
        let fm = FileManager.default
        let directory = (heartbeatFilePath as NSString).deletingLastPathComponent

        if !fm.fileExists(atPath: directory) {
            try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }

        let data = Data(timestamp.utf8)
        if fm.fileExists(atPath: heartbeatFilePath) {
            try? data.write(to: URL(fileURLWithPath: heartbeatFilePath))
        } else {
            fm.createFile(atPath: heartbeatFilePath, contents: data, attributes: [.posixPermissions: 0o600])
        }
    }
}
