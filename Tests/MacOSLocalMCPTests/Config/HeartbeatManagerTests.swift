import XCTest
@testable import MacOSLocalMCP

final class HeartbeatManagerTests: XCTestCase {

    var tempDir: String!
    var heartbeatPath: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "macos-local-mcp-heartbeat-\(UUID().uuidString)"
        heartbeatPath = tempDir + "/heartbeat"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitWithCustomPath() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        XCTAssertEqual(manager.heartbeatFilePath, heartbeatPath)
    }

    func testInitWithDefaultPath() {
        let manager = HeartbeatManager()
        XCTAssertTrue(manager.heartbeatFilePath.hasSuffix("heartbeat"))
        XCTAssertTrue(manager.heartbeatFilePath.contains(".macos-local-mcp"))
    }

    func testDefaultInterval() {
        let manager = HeartbeatManager()
        XCTAssertEqual(manager.intervalSeconds, 30)
    }

    func testCustomInterval() {
        let manager = HeartbeatManager(intervalSeconds: 5)
        XCTAssertEqual(manager.intervalSeconds, 5)
    }

    // MARK: - isRunning State

    func testIsRunningInitiallyFalse() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        XCTAssertFalse(manager.isRunning)
    }

    func testStartSetsIsRunning() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.start()
        XCTAssertTrue(manager.isRunning)
        manager.stop()
    }

    func testStopClearsIsRunning() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.start()
        manager.stop()
        XCTAssertFalse(manager.isRunning)
    }

    // MARK: - Heartbeat File

    func testStartWritesHeartbeatFile() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.start()

        // Give it a moment to write
        let expectation = XCTestExpectation(description: "Heartbeat file written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: heartbeatPath))
        manager.stop()
    }

    func testHeartbeatFileContainsISO8601Timestamp() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.start()

        let expectation = XCTestExpectation(description: "Heartbeat written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        let content = try? String(contentsOfFile: heartbeatPath, encoding: .utf8)
        XCTAssertNotNil(content)

        if let ts = content {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            XCTAssertNotNil(formatter.date(from: ts), "Heartbeat is not ISO 8601: \(ts)")
        }

        manager.stop()
    }

    func testStartTwiceDoesNotCrash() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.start()
        manager.start() // Should be a no-op
        XCTAssertTrue(manager.isRunning)
        manager.stop()
    }

    func testStopWithoutStartDoesNotCrash() {
        let manager = HeartbeatManager(heartbeatFilePath: heartbeatPath)
        manager.stop() // Should be a no-op
        XCTAssertFalse(manager.isRunning)
    }

    func testHeartbeatCreatesParentDirectory() {
        let nestedPath = tempDir + "/nested/heartbeat"
        let manager = HeartbeatManager(heartbeatFilePath: nestedPath)
        manager.start()

        let expectation = XCTestExpectation(description: "Heartbeat written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath))
        manager.stop()
    }
}
