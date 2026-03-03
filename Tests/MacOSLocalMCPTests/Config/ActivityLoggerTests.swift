import XCTest
@testable import MacOSLocalMCP

final class ActivityLoggerTests: XCTestCase {

    var tempDir: String!
    var logFilePath: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "macos-local-mcp-logger-\(UUID().uuidString)"
        logFilePath = tempDir + "/activity.jsonl"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitWithCustomPath() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        XCTAssertEqual(logger.logFilePath, logFilePath)
    }

    func testInitWithDefaultPath() {
        let logger = ActivityLogger()
        XCTAssertTrue(logger.logFilePath.hasSuffix("activity.jsonl"))
        XCTAssertTrue(logger.logFilePath.contains(".macos-local-mcp"))
    }

    // MARK: - Log Success

    func testLogSuccessCreatesFileAndWritesEntry() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logSuccess(tool: "list_reminders", params: ["list": "Work"], durationMs: 150, resultCount: 5)

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        XCTAssertNotNil(content)

        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 1)

        if let data = lines.first?.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["tool"] as? String, "list_reminders")
            XCTAssertEqual(json["status"] as? String, "success")
            XCTAssertEqual(json["duration_ms"] as? Int, 150)
            XCTAssertEqual(json["result_count"] as? Int, 5)
            XCTAssertNotNil(json["ts"])
        } else {
            XCTFail("Failed to parse log entry JSON")
        }
    }

    // MARK: - Log Error

    func testLogErrorWritesEntryWithError() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logError(tool: "create_event", params: [:], durationMs: 50, error: "Permission denied")

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 1)

        if let data = lines.first?.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["status"] as? String, "error")
            XCTAssertEqual(json["error"] as? String, "Permission denied")
            XCTAssertNil(json["result_count"])
        } else {
            XCTFail("Failed to parse log entry JSON")
        }
    }

    // MARK: - Log Confirmation Required

    func testLogConfirmationRequired() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logConfirmationRequired(tool: "send_message", params: ["to": "+1234567890"])

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 1)

        if let data = lines.first?.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertEqual(json["status"] as? String, "confirmation_required")
            XCTAssertEqual(json["tool"] as? String, "send_message")
            XCTAssertEqual(json["duration_ms"] as? Int, 0)
        } else {
            XCTFail("Failed to parse log entry JSON")
        }
    }

    // MARK: - Multiple Entries

    func testMultipleEntriesAppended() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logSuccess(tool: "tool1", params: [:], durationMs: 10, resultCount: 1)
        logger.logSuccess(tool: "tool2", params: [:], durationMs: 20, resultCount: 2)
        logger.logError(tool: "tool3", params: [:], durationMs: 30, error: "err")

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        XCTAssertEqual(lines.count, 3)
    }

    // MARK: - Directory Creation

    func testCreatesParentDirectoryIfNeeded() {
        let nestedPath = tempDir + "/nested/deep/activity.jsonl"
        let logger = ActivityLogger(logFilePath: nestedPath)
        logger.logSuccess(tool: "test", params: [:], durationMs: 1, resultCount: 0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath))
    }

    // MARK: - JSONL Format

    func testEachLineIsValidJSON() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logSuccess(tool: "a", params: [:], durationMs: 1, resultCount: 0)
        logger.logError(tool: "b", params: [:], durationMs: 2, error: "e")

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        let lines = content?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []

        for line in lines {
            let data = line.data(using: .utf8)!
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data), "Line is not valid JSON: \(line)")
        }
    }

    // MARK: - Timestamp Format

    func testTimestampIsISO8601() {
        let logger = ActivityLogger(logFilePath: logFilePath)
        logger.logSuccess(tool: "test", params: [:], durationMs: 1, resultCount: 0)

        let content = try? String(contentsOfFile: logFilePath, encoding: .utf8)
        if let data = content?.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data.split(separator: UInt8(ascii: "\n")).first ?? Data()) as? [String: Any],
           let ts = json["ts"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            XCTAssertNotNil(formatter.date(from: ts), "Timestamp is not valid ISO 8601: \(ts)")
        }
    }
}
