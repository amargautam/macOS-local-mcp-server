import Foundation

/// Protocol for interacting with the macOS Calendar app via AppleScript/EventKit.
protocol CalendarProviding {
    func listCalendars() async throws -> [[String: Any]]
    func listEvents(startDate: Date, endDate: Date, calendarName: String?) async throws -> [[String: Any]]
    func createEvent(title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String?, notes: String?, calendarName: String?) async throws -> [String: Any]
    func updateEvent(id: String, title: String?, startDate: Date?, endDate: Date?, location: String?, notes: String?) async throws -> [String: Any]
    func deleteEvent(id: String, confirmation: Bool) async throws -> [String: Any]
    func checkAvailability(startDate: Date, endDate: Date) async throws -> [[String: Any]]
    func searchEvents(query: String) async throws -> [[String: Any]]
    func findConflicts(startDate: Date, endDate: Date) async throws -> [[String: Any]]
    func findGaps(startDate: Date, endDate: Date, minMinutes: Int?) async throws -> [[String: Any]]
    func getCalendarStats(startDate: Date, endDate: Date) async throws -> [String: Any]
    func bulkDeclineEvents(ids: [String], confirmation: Bool) async throws -> [[String: Any]]
}
