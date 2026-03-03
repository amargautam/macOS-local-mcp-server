import XCTest
@testable import MacOSLocalMCP

final class CalendarToolTests: XCTestCase {

    // MARK: - Helpers

    private func makeHandlers(provider: MockCalendarProvider) -> [String: MCPToolHandler] {
        let tool = CalendarTool(provider: provider)
        return Dictionary(uniqueKeysWithValues: tool.createHandlers().map { ($0.toolName, $0) })
    }

    private func call(_ handler: MCPToolHandler, args: [String: JSONValue]? = nil) async throws -> MCPToolResult {
        try await handler.handle(arguments: args)
    }

    private func isError(_ result: MCPToolResult) -> Bool {
        result.isError == true
    }

    private func text(_ result: MCPToolResult) -> String {
        result.content.first?.text ?? ""
    }

    // MARK: - list_calendars

    func test_listCalendars_happyPath_returnsJSON() async throws {
        let provider = MockCalendarProvider()
        provider.listCalendarsResult = [
            ["id": "cal-1", "name": "Personal"],
            ["id": "cal-2", "name": "Work"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_calendars"])

        let result = try await call(handler)

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listCalendarsCalled)
        XCTAssertTrue(text(result).contains("Personal"))
        XCTAssertTrue(text(result).contains("Work"))
    }

    func test_listCalendars_emptyResult_returnsEmptyArray() async throws {
        let provider = MockCalendarProvider()
        provider.listCalendarsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_calendars"])

        let result = try await call(handler)

        XCTAssertFalse(isError(result))
        XCTAssertEqual(text(result), "[]")
    }

    func test_listCalendars_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.listCalendarsError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_calendars"])

        let result = try await call(handler)

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Permission denied"))
    }

    // MARK: - list_events

    func test_listEvents_happyPath_returnsJSON() async throws {
        let provider = MockCalendarProvider()
        provider.listEventsResult = [
            ["id": "evt-1", "title": "Team meeting", "startDate": "2026-03-01T10:00:00Z"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listEventsCalled)
        XCTAssertTrue(text(result).contains("Team meeting"))
    }

    func test_listEvents_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.listEventsCalled)
    }

    func test_listEvents_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.listEventsCalled)
    }

    func test_listEvents_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.listEventsCalled)
    }

    func test_listEvents_invalidStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "start_date": .string("not-a-date"),
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.listEventsCalled)
    }

    func test_listEvents_withCalendarNameFilter_passesThrough() async throws {
        let provider = MockCalendarProvider()
        provider.listEventsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-31T23:59:59Z"),
            "calendar_name": .string("Work")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listEventsCalled)
    }

    func test_listEvents_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.listEventsError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_events"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Fetch failed"))
    }

    // MARK: - create_event

    func test_createEvent_happyPath_returnsCreatedEvent() async throws {
        let provider = MockCalendarProvider()
        provider.createEventResult = ["id": "evt-new", "title": "Dentist"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "title": .string("Dentist"),
            "start_date": .string("2026-03-15T09:00:00Z"),
            "end_date": .string("2026-03-15T10:00:00Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.createEventCalled)
        XCTAssertEqual(provider.lastCreateEventTitle, "Dentist")
        XCTAssertTrue(text(result).contains("Dentist"))
    }

    func test_createEvent_missingTitle_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T09:00:00Z"),
            "end_date": .string("2026-03-15T10:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.createEventCalled)
    }

    func test_createEvent_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "title": .string("Dentist"),
            "end_date": .string("2026-03-15T10:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.createEventCalled)
    }

    func test_createEvent_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "title": .string("Dentist"),
            "start_date": .string("2026-03-15T09:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.createEventCalled)
    }

    func test_createEvent_withOptionalFields_passesThrough() async throws {
        let provider = MockCalendarProvider()
        provider.createEventResult = ["id": "evt-new", "title": "Meeting"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "title": .string("Meeting"),
            "start_date": .string("2026-03-15T09:00:00Z"),
            "end_date": .string("2026-03-15T10:00:00Z"),
            "is_all_day": .bool(false),
            "location": .string("Conference Room A"),
            "notes": .string("Bring slides"),
            "calendar_name": .string("Work")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.createEventCalled)
    }

    func test_createEvent_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.createEventError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Create failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_event"])

        let result = try await call(handler, args: [
            "title": .string("Meeting"),
            "start_date": .string("2026-03-15T09:00:00Z"),
            "end_date": .string("2026-03-15T10:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Create failed"))
    }

    // MARK: - update_event

    func test_updateEvent_happyPath_returnsUpdated() async throws {
        let provider = MockCalendarProvider()
        provider.updateEventResult = ["id": "evt-1", "title": "Updated meeting"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_event"])

        let result = try await call(handler, args: [
            "id": .string("evt-1"),
            "title": .string("Updated meeting")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.updateEventCalled)
        XCTAssertTrue(text(result).contains("Updated meeting"))
    }

    func test_updateEvent_missingId_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_event"])

        let result = try await call(handler, args: ["title": .string("No ID")])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.updateEventCalled)
    }

    func test_updateEvent_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_event"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.updateEventCalled)
    }

    func test_updateEvent_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.updateEventError = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_event"])

        let result = try await call(handler, args: ["id": .string("evt-1")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Update failed"))
    }

    // MARK: - delete_event

    func test_deleteEvent_happyPath_returnsDeleted() async throws {
        let provider = MockCalendarProvider()
        provider.deleteEventResult = ["id": "evt-1", "deleted": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["delete_event"])

        let result = try await call(handler, args: [
            "id": .string("evt-1"),
            "confirmation": .bool(true)
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.deleteEventCalled)
        XCTAssertEqual(provider.lastDeleteEventId, "evt-1")
    }

    func test_deleteEvent_missingId_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["delete_event"])

        let result = try await call(handler, args: ["confirmation": .bool(true)])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.deleteEventCalled)
    }

    func test_deleteEvent_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["delete_event"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.deleteEventCalled)
    }

    func test_deleteEvent_withoutConfirmation_usesDefaultFalse() async throws {
        // When no confirmation param is provided, it defaults to false and the provider is still called
        let provider = MockCalendarProvider()
        provider.deleteEventResult = ["id": "evt-1", "deleted": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["delete_event"])

        let result = try await call(handler, args: ["id": .string("evt-1")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.deleteEventCalled)
    }

    func test_deleteEvent_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.deleteEventError = NSError(domain: "test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["delete_event"])

        let result = try await call(handler, args: [
            "id": .string("evt-1"),
            "confirmation": .bool(true)
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Delete failed"))
    }

    // MARK: - check_availability

    func test_checkAvailability_happyPath_returnsSlots() async throws {
        let provider = MockCalendarProvider()
        provider.checkAvailabilityResult = [
            ["start": "2026-03-15T10:00:00Z", "end": "2026-03-15T11:00:00Z", "isFree": true]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["check_availability"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z"),
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.checkAvailabilityCalled)
        XCTAssertTrue(text(result).contains("isFree"))
    }

    func test_checkAvailability_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["check_availability"])

        let result = try await call(handler, args: [
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.checkAvailabilityCalled)
    }

    func test_checkAvailability_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["check_availability"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.checkAvailabilityCalled)
    }

    func test_checkAvailability_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["check_availability"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.checkAvailabilityCalled)
    }

    func test_checkAvailability_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.checkAvailabilityError = NSError(domain: "test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Check failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["check_availability"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z"),
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Check failed"))
    }

    // MARK: - search_events

    func test_searchEvents_happyPath_returnsMatches() async throws {
        let provider = MockCalendarProvider()
        provider.searchEventsResult = [
            ["id": "evt-2", "title": "Sprint review"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_events"])

        let result = try await call(handler, args: ["query": .string("Sprint")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.searchEventsCalled)
        XCTAssertEqual(provider.lastSearchQuery, "Sprint")
        XCTAssertTrue(text(result).contains("Sprint review"))
    }

    func test_searchEvents_missingQuery_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_events"])

        let result = try await call(handler, args: [:])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.searchEventsCalled)
    }

    func test_searchEvents_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_events"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.searchEventsCalled)
    }

    func test_searchEvents_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.searchEventsError = NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_events"])

        let result = try await call(handler, args: ["query": .string("test")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Search failed"))
    }

    // MARK: - find_conflicts

    func test_findConflicts_happyPath_returnsConflictGroups() async throws {
        let provider = MockCalendarProvider()
        provider.findConflictsResult = [
            ["event1": "evt-1", "event2": "evt-2", "overlapStart": "2026-03-15T10:00:00Z", "overlapEnd": "2026-03-15T11:00:00Z"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z"),
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.findConflictsCalled)
        XCTAssertTrue(text(result).contains("evt-1"))
        XCTAssertTrue(text(result).contains("evt-2"))
    }

    func test_findConflicts_noConflicts_returnsEmptyArray() async throws {
        let provider = MockCalendarProvider()
        provider.findConflictsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z"),
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertEqual(text(result), "[]")
    }

    func test_findConflicts_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: [
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findConflictsCalled)
    }

    func test_findConflicts_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findConflictsCalled)
    }

    func test_findConflicts_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findConflictsCalled)
    }

    func test_findConflicts_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.findConflictsError = NSError(domain: "test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Conflict check failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_conflicts"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T00:00:00Z"),
            "end_date": .string("2026-03-15T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Conflict check failed"))
    }

    // MARK: - find_gaps

    func test_findGaps_happyPath_returnsGaps() async throws {
        let provider = MockCalendarProvider()
        provider.findGapsResult = [
            ["start": "2026-03-15T08:00:00Z", "end": "2026-03-15T10:00:00Z", "minutes": 120]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T08:00:00Z"),
            "end_date": .string("2026-03-15T18:00:00Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.findGapsCalled)
        XCTAssertTrue(text(result).contains("minutes"))
    }

    func test_findGaps_withMinMinutes_passesThrough() async throws {
        let provider = MockCalendarProvider()
        provider.findGapsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        _ = try await call(handler, args: [
            "start_date": .string("2026-03-15T08:00:00Z"),
            "end_date": .string("2026-03-15T18:00:00Z"),
            "min_minutes": .int(60)
        ])

        XCTAssertTrue(provider.findGapsCalled)
        XCTAssertEqual(provider.lastFindGapsMinMinutes, 60)
    }

    func test_findGaps_defaultMinMinutes_is30() async throws {
        let provider = MockCalendarProvider()
        provider.findGapsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        _ = try await call(handler, args: [
            "start_date": .string("2026-03-15T08:00:00Z"),
            "end_date": .string("2026-03-15T18:00:00Z")
        ])

        XCTAssertTrue(provider.findGapsCalled)
        XCTAssertEqual(provider.lastFindGapsMinMinutes, 30)
    }

    func test_findGaps_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        let result = try await call(handler, args: [
            "end_date": .string("2026-03-15T18:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findGapsCalled)
    }

    func test_findGaps_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T08:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findGapsCalled)
    }

    func test_findGaps_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.findGapsCalled)
    }

    func test_findGaps_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.findGapsError = NSError(domain: "test", code: 9, userInfo: [NSLocalizedDescriptionKey: "Gaps failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_gaps"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-15T08:00:00Z"),
            "end_date": .string("2026-03-15T18:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Gaps failed"))
    }

    // MARK: - get_calendar_stats

    func test_getCalendarStats_happyPath_returnsStats() async throws {
        let provider = MockCalendarProvider()
        provider.getCalendarStatsResult = [
            "totalEvents": 5,
            "totalHours": 10.5,
            "busiestDay": "2026-03-15",
            "eventsPerCalendar": ["Work": 3, "Personal": 2]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["get_calendar_stats"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.getCalendarStatsCalled)
        XCTAssertTrue(text(result).contains("totalEvents"))
        XCTAssertTrue(text(result).contains("totalHours"))
    }

    func test_getCalendarStats_missingStartDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["get_calendar_stats"])

        let result = try await call(handler, args: [
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.getCalendarStatsCalled)
    }

    func test_getCalendarStats_missingEndDate_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["get_calendar_stats"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.getCalendarStatsCalled)
    }

    func test_getCalendarStats_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["get_calendar_stats"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.getCalendarStatsCalled)
    }

    func test_getCalendarStats_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.getCalendarStatsError = NSError(domain: "test", code: 10, userInfo: [NSLocalizedDescriptionKey: "Stats failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["get_calendar_stats"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Stats failed"))
    }

    // MARK: - bulk_decline_events

    func test_bulkDeclineEvents_happyPath_withConfirmation_returnsArray() async throws {
        let provider = MockCalendarProvider()
        provider.bulkDeclineEventsResult = [
            ["id": "evt-1", "deleted": true],
            ["id": "evt-2", "deleted": true]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "ids": .array([.string("evt-1"), .string("evt-2")]),
            "confirmation": .bool(true)
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.bulkDeclineEventsCalled)
        XCTAssertEqual(provider.lastBulkDeclineEventIds, ["evt-1", "evt-2"])
        XCTAssertTrue(text(result).contains("evt-1"))
        XCTAssertTrue(text(result).contains("evt-2"))
    }

    func test_bulkDeclineEvents_withoutConfirmation_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "ids": .array([.string("evt-1")]),
            "confirmation": .bool(false)
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkDeclineEventsCalled)
        XCTAssertTrue(text(result).lowercased().contains("confirmation"))
    }

    func test_bulkDeclineEvents_missingConfirmation_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "ids": .array([.string("evt-1")])
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkDeclineEventsCalled)
    }

    func test_bulkDeclineEvents_missingIds_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "confirmation": .bool(true)
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkDeclineEventsCalled)
        XCTAssertTrue(text(result).lowercased().contains("ids"))
    }

    func test_bulkDeclineEvents_emptyIds_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "ids": .array([]),
            "confirmation": .bool(true)
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkDeclineEventsCalled)
    }

    func test_bulkDeclineEvents_nilArguments_returnsError() async throws {
        let provider = MockCalendarProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkDeclineEventsCalled)
    }

    func test_bulkDeclineEvents_providerError_returnsError() async throws {
        let provider = MockCalendarProvider()
        provider.bulkDeclineEventsError = NSError(domain: "test", code: 11, userInfo: [NSLocalizedDescriptionKey: "Bulk delete failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_decline_events"])

        let result = try await call(handler, args: [
            "ids": .array([.string("evt-1")]),
            "confirmation": .bool(true)
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Bulk delete failed"))
    }

    // MARK: - Handler registration

    func test_createHandlers_registersAllElevenTools() {
        let provider = MockCalendarProvider()
        let tool = CalendarTool(provider: provider)
        let handlers = tool.createHandlers()

        let names = Set(handlers.map { $0.toolName })
        XCTAssertEqual(names.count, 11)
        XCTAssertTrue(names.contains("list_calendars"))
        XCTAssertTrue(names.contains("list_events"))
        XCTAssertTrue(names.contains("create_event"))
        XCTAssertTrue(names.contains("update_event"))
        XCTAssertTrue(names.contains("delete_event"))
        XCTAssertTrue(names.contains("check_availability"))
        XCTAssertTrue(names.contains("search_events"))
        XCTAssertTrue(names.contains("find_conflicts"))
        XCTAssertTrue(names.contains("find_gaps"))
        XCTAssertTrue(names.contains("get_calendar_stats"))
        XCTAssertTrue(names.contains("bulk_decline_events"))
    }
}
