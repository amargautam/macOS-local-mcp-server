import XCTest
@testable import MacOSLocalMCPAdmin

final class ActivityEntryTests: XCTestCase {

    func test_isSuccess_trueForSuccessStatus() {
        let entry = ActivityEntry(ts: "2026-01-01T00:00:00Z", tool: "t", status: "success", duration_ms: 1)
        XCTAssertTrue(entry.isSuccess)
        XCTAssertFalse(entry.isError)
    }

    func test_isError_trueForErrorStatus() {
        let entry = ActivityEntry(ts: "2026-01-01T00:00:00Z", tool: "t", status: "error", duration_ms: 1, error: "oh no")
        XCTAssertTrue(entry.isError)
        XCTAssertFalse(entry.isSuccess)
    }

    func test_date_parsesISO8601WithFractionalSeconds() {
        let entry = ActivityEntry(ts: "2026-01-02T12:30:00.000Z", tool: "t", status: "success", duration_ms: 1)
        XCTAssertNotNil(entry.date)
    }

    func test_date_parsesISO8601WithoutFractionalSeconds() {
        let entry = ActivityEntry(ts: "2026-01-02T12:30:00Z", tool: "t", status: "success", duration_ms: 1)
        XCTAssertNotNil(entry.date)
    }

    func test_date_returnsNilForBadTimestamp() {
        let entry = ActivityEntry(ts: "not-a-date", tool: "t", status: "success", duration_ms: 1)
        XCTAssertNil(entry.date)
    }

    func test_id_isUnique_forDifferentToolsAtSameTime() {
        let e1 = ActivityEntry(ts: "2026-01-01T00:00:00Z", tool: "tool_a", status: "success", duration_ms: 1)
        let e2 = ActivityEntry(ts: "2026-01-01T00:00:00Z", tool: "tool_b", status: "success", duration_ms: 1)
        XCTAssertNotEqual(e1.id, e2.id)
    }
}
