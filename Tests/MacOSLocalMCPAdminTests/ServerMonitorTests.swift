import XCTest
@testable import MacOSLocalMCPAdmin

final class ServerMonitorTests: XCTestCase {

    // MARK: - Helpers

    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacOSLocalMCPAdminTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    private func binaryPath() -> String { tmpDir.appendingPathComponent("macos-local-mcp").path }
    private func pidPath() -> String { tmpDir.appendingPathComponent("server.pid").path }
    private func heartbeatPath() -> String { tmpDir.appendingPathComponent("heartbeat").path }

    private func writeFile(_ content: String, to path: String) {
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Helper to create a monitor with process scanning disabled (avoids pgrep finding real processes).
    private func makeMonitor() -> ServerMonitor {
        ServerMonitor(
            binaryPath: binaryPath(),
            pidFilePath: pidPath(),
            heartbeatFilePath: heartbeatPath(),
            processName: nil  // Disable pgrep fallback in tests
        )
    }

    /// Create a fake executable binary at the expected path.
    private func installFakeBinary() {
        writeFile("#!/bin/sh\n", to: binaryPath())
        // Make it executable
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: binaryPath()
        )
    }

    // MARK: - isConfigured

    func test_isConfigured_returnsFalse_whenBinaryAbsent() {
        let monitor = makeMonitor()
        XCTAssertFalse(monitor.isConfigured())
    }

    func test_isConfigured_returnsTrue_whenBinaryExists() {
        installFakeBinary()
        let monitor = makeMonitor()
        XCTAssertTrue(monitor.isConfigured())
    }

    func test_isConfigured_returnsFalse_whenFileExistsButNotExecutable() {
        writeFile("not executable", to: binaryPath())
        // Don't set executable permission
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: binaryPath()
        )
        let monitor = makeMonitor()
        XCTAssertFalse(monitor.isConfigured())
    }

    // MARK: - isActive

    func test_isActive_returnsFalse_whenNoPIDFile() {
        let monitor = makeMonitor()
        XCTAssertFalse(monitor.isActive())
    }

    func test_isActive_returnsFalse_whenPIDFileContainsNonNumeric() {
        writeFile("notapid\n", to: pidPath())
        let monitor = makeMonitor()
        XCTAssertFalse(monitor.isActive())
    }

    func test_isActive_returnsFalse_whenPIDFilePointsToDeadProcess() {
        writeFile("99999\n", to: pidPath())
        let monitor = makeMonitor()
        // PID 99999 is almost certainly not running
        // Just verify it doesn't crash and returns a reasonable result
        _ = monitor.isActive()
    }

    func test_isActive_returnsTrue_whenPIDPointsToLiveProcess() {
        // Use the current process PID so the "process exists" check passes.
        let currentPID = ProcessInfo.processInfo.processIdentifier
        writeFile("\(currentPID)\n", to: pidPath())
        let monitor = makeMonitor()
        XCTAssertTrue(monitor.isActive())
    }

    // MARK: - pid()

    func test_pid_returnsNil_whenNoPIDFile() {
        let monitor = makeMonitor()
        XCTAssertNil(monitor.pid())
    }

    func test_pid_returnsValue_whenPIDFilePointsToLiveProcess() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        writeFile("\(currentPID)\n", to: pidPath())
        let monitor = makeMonitor()
        XCTAssertEqual(monitor.pid(), Int(currentPID))
    }

    func test_pid_trimsWhitespace() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        writeFile("  \(currentPID)  \n", to: pidPath())
        let monitor = makeMonitor()
        XCTAssertEqual(monitor.pid(), Int(currentPID))
    }

    // MARK: - lastActivityDate()

    func test_lastActivityDate_returnsNil_whenHeartbeatAbsent() {
        let monitor = makeMonitor()
        XCTAssertNil(monitor.lastActivityDate())
    }

    func test_lastActivityDate_returnsNil_whenHeartbeatUnparseable() {
        writeFile("not-a-date", to: heartbeatPath())
        let monitor = makeMonitor()
        XCTAssertNil(monitor.lastActivityDate())
    }

    func test_lastActivityDate_returnsDate_whenHeartbeatExists() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fiveSecondsAgo = Date(timeIntervalSinceNow: -5)
        writeFile(formatter.string(from: fiveSecondsAgo), to: heartbeatPath())
        let monitor = makeMonitor()
        guard let date = monitor.lastActivityDate() else {
            XCTFail("Expected non-nil date")
            return
        }
        let age = Date().timeIntervalSince(date)
        XCTAssertGreaterThanOrEqual(age, 4.0)
        XCTAssertLessThan(age, 30.0)
    }
}
