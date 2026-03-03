import Foundation
@testable import MacOSLocalMCP

final class MockCalendarProvider: CalendarProviding {
    var listCalendarsCalled = false
    var listEventsCalled = false
    var createEventCalled = false
    var updateEventCalled = false
    var deleteEventCalled = false
    var checkAvailabilityCalled = false
    var searchEventsCalled = false
    var findConflictsCalled = false
    var findGapsCalled = false
    var getCalendarStatsCalled = false
    var bulkDeclineEventsCalled = false

    var listCalendarsResult: [[String: Any]] = []
    var listEventsResult: [[String: Any]] = []
    var createEventResult: [String: Any] = [:]
    var updateEventResult: [String: Any] = [:]
    var deleteEventResult: [String: Any] = [:]
    var checkAvailabilityResult: [[String: Any]] = []
    var searchEventsResult: [[String: Any]] = []
    var findConflictsResult: [[String: Any]] = []
    var findGapsResult: [[String: Any]] = []
    var getCalendarStatsResult: [String: Any] = [:]
    var bulkDeclineEventsResult: [[String: Any]] = []

    var listCalendarsError: Error?
    var listEventsError: Error?
    var createEventError: Error?
    var updateEventError: Error?
    var deleteEventError: Error?
    var checkAvailabilityError: Error?
    var searchEventsError: Error?
    var findConflictsError: Error?
    var findGapsError: Error?
    var getCalendarStatsError: Error?
    var bulkDeclineEventsError: Error?

    var lastCreateEventTitle: String?
    var lastDeleteEventId: String?
    var lastSearchQuery: String?
    var lastFindGapsMinMinutes: Int?
    var lastBulkDeclineEventIds: [String]?

    func listCalendars() async throws -> [[String: Any]] {
        listCalendarsCalled = true
        if let error = listCalendarsError { throw error }
        return listCalendarsResult
    }

    func listEvents(startDate: Date, endDate: Date, calendarName: String?) async throws -> [[String: Any]] {
        listEventsCalled = true
        if let error = listEventsError { throw error }
        return listEventsResult
    }

    func createEvent(title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String?, notes: String?, calendarName: String?) async throws -> [String: Any] {
        createEventCalled = true
        lastCreateEventTitle = title
        if let error = createEventError { throw error }
        return createEventResult
    }

    func updateEvent(id: String, title: String?, startDate: Date?, endDate: Date?, location: String?, notes: String?) async throws -> [String: Any] {
        updateEventCalled = true
        if let error = updateEventError { throw error }
        return updateEventResult
    }

    func deleteEvent(id: String, confirmation: Bool) async throws -> [String: Any] {
        deleteEventCalled = true
        lastDeleteEventId = id
        if let error = deleteEventError { throw error }
        return deleteEventResult
    }

    func checkAvailability(startDate: Date, endDate: Date) async throws -> [[String: Any]] {
        checkAvailabilityCalled = true
        if let error = checkAvailabilityError { throw error }
        return checkAvailabilityResult
    }

    func searchEvents(query: String) async throws -> [[String: Any]] {
        searchEventsCalled = true
        lastSearchQuery = query
        if let error = searchEventsError { throw error }
        return searchEventsResult
    }

    func findConflicts(startDate: Date, endDate: Date) async throws -> [[String: Any]] {
        findConflictsCalled = true
        if let error = findConflictsError { throw error }
        return findConflictsResult
    }

    func findGaps(startDate: Date, endDate: Date, minMinutes: Int?) async throws -> [[String: Any]] {
        findGapsCalled = true
        lastFindGapsMinMinutes = minMinutes
        if let error = findGapsError { throw error }
        return findGapsResult
    }

    func getCalendarStats(startDate: Date, endDate: Date) async throws -> [String: Any] {
        getCalendarStatsCalled = true
        if let error = getCalendarStatsError { throw error }
        return getCalendarStatsResult
    }

    func bulkDeclineEvents(ids: [String], confirmation: Bool) async throws -> [[String: Any]] {
        bulkDeclineEventsCalled = true
        lastBulkDeclineEventIds = ids
        if let error = bulkDeclineEventsError { throw error }
        return bulkDeclineEventsResult
    }
}
