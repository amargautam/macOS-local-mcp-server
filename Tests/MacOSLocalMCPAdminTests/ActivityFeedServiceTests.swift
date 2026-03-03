import XCTest
@testable import MacOSLocalMCPAdmin

final class ActivityFeedServiceTests: XCTestCase {

    // MARK: - Helpers

    private var tmpDir: URL!
    private var logPath: String { tmpDir.appendingPathComponent("activity.jsonl").path }

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActivityFeedTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    private func writeLine(_ json: String) {
        let line = json + "\n"
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }

    // MARK: - loadEntries

    func test_loadEntries_returnsEmpty_whenFileAbsent() {
        let service = ActivityFeedService(logFilePath: logPath)
        XCTAssertEqual(service.loadEntries(limit: 100), [])
    }

    func test_loadEntries_returnsEmpty_whenFileEmpty() {
        FileManager.default.createFile(atPath: logPath, contents: nil)
        let service = ActivityFeedService(logFilePath: logPath)
        XCTAssertEqual(service.loadEntries(limit: 100), [])
    }

    func test_loadEntries_skipsInvalidLines() {
        writeLine("not valid json {{{{")
        writeLine("""
        {"ts":"2026-01-01T00:00:00.000Z","tool":"list_reminders","status":"success","duration_ms":42,"result_count":3}
        """)
        let service = ActivityFeedService(logFilePath: logPath)
        let entries = service.loadEntries(limit: 100)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].tool, "list_reminders")
    }

    func test_loadEntries_parsesAllFields() {
        writeLine("""
        {"ts":"2026-01-02T12:00:00.000Z","tool":"send_message","status":"error","duration_ms":10,"error":"Permission denied"}
        """)
        let service = ActivityFeedService(logFilePath: logPath)
        let entries = service.loadEntries(limit: 100)
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.ts, "2026-01-02T12:00:00.000Z")
        XCTAssertEqual(entry.tool, "send_message")
        XCTAssertEqual(entry.status, "error")
        XCTAssertEqual(entry.duration_ms, 10)
        XCTAssertNil(entry.result_count)
        XCTAssertEqual(entry.error, "Permission denied")
    }

    func test_loadEntries_respectsLimit() {
        for i in 0..<10 {
            writeLine("""
            {"ts":"2026-01-01T00:00:0\(i).000Z","tool":"tool_\(i)","status":"success","duration_ms":1}
            """)
        }
        let service = ActivityFeedService(logFilePath: logPath)
        let entries = service.loadEntries(limit: 5)
        XCTAssertEqual(entries.count, 5)
    }

    func test_loadEntries_returnsNewestFirst() {
        writeLine("""
        {"ts":"2026-01-01T00:00:01.000Z","tool":"first","status":"success","duration_ms":1}
        """)
        writeLine("""
        {"ts":"2026-01-01T00:00:02.000Z","tool":"second","status":"success","duration_ms":1}
        """)
        let service = ActivityFeedService(logFilePath: logPath)
        let entries = service.loadEntries(limit: 100)
        // Most recent entry should be first
        XCTAssertEqual(entries[0].tool, "second")
        XCTAssertEqual(entries[1].tool, "first")
    }

    // MARK: - entriesCount

    func test_entriesCount_returnsZero_whenFileAbsent() {
        let service = ActivityFeedService(logFilePath: logPath)
        XCTAssertEqual(service.entriesCount(), 0)
    }

    func test_entriesCount_returnsCorrectCount() {
        for i in 0..<7 {
            writeLine("""
            {"ts":"2026-01-01T00:00:0\(i).000Z","tool":"t","status":"success","duration_ms":1}
            """)
        }
        // Add one invalid line — should not be counted
        writeLine("bad line")
        let service = ActivityFeedService(logFilePath: logPath)
        XCTAssertEqual(service.entriesCount(), 7)
    }
}
