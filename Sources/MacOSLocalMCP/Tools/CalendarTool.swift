import Foundation

/// Provides MCPToolHandler instances for all Calendar-related tools.
final class CalendarTool {
    private let provider: CalendarProviding

    init(provider: CalendarProviding) {
        self.provider = provider
    }

    /// Returns all 11 handler objects for the Calendar module.
    func createHandlers() -> [MCPToolHandler] {
        [
            listCalendarsHandler(),
            listEventsHandler(),
            createEventHandler(),
            updateEventHandler(),
            deleteEventHandler(),
            checkAvailabilityHandler(),
            searchEventsHandler(),
            findConflictsHandler(),
            findGapsHandler(),
            getCalendarStatsHandler(),
            bulkDeclineEventsHandler()
        ]
    }

    // MARK: - Private helpers

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FormatterBasic.date(from: string)
    }

    static func serialize(dict: [String: Any]) -> MCPToolResult {
        do {
            let jsonValue = JSONValue.from(dictionary: dict)
            let data = try JSONEncoder().encode(jsonValue)
            return .text(String(data: data, encoding: .utf8) ?? "{}")
        } catch {
            return .error("Failed to encode result: \(error.localizedDescription)")
        }
    }

    static func serialize(array: [[String: Any]]) -> MCPToolResult {
        do {
            let jsonValue = JSONValue.from(arrayOfDictionaries: array)
            let data = try JSONEncoder().encode(jsonValue)
            return .text(String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            return .error("Failed to encode result: \(error.localizedDescription)")
        }
    }

    // MARK: - Handlers
    // Each handler captures the provider strongly so it stays alive independently of CalendarTool.

    private func listCalendarsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "list_calendars") { _ in
            do {
                let calendars = try await provider.listCalendars()
                return CalendarTool.serialize(array: calendars)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listEventsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "list_events") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }

            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601 (e.g. 2026-03-01T00:00:00Z)")
            }

            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601 (e.g. 2026-03-31T23:59:59Z)")
            }

            let calendarName: String? = {
                guard case .string(let v) = args["calendar_name"] else { return nil }
                return v
            }()

            do {
                let events = try await provider.listEvents(
                    startDate: startDate,
                    endDate: endDate,
                    calendarName: calendarName
                )
                return CalendarTool.serialize(array: events)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func createEventHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "create_event") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: title, start_date, end_date")
            }

            guard case .string(let title) = args["title"] else {
                return .error("Missing required parameter: title")
            }

            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601")
            }

            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }

            let isAllDay: Bool = {
                guard case .bool(let v) = args["is_all_day"] else { return false }
                return v
            }()

            let location: String? = {
                guard case .string(let v) = args["location"] else { return nil }
                return v
            }()

            let notes: String? = {
                guard case .string(let v) = args["notes"] else { return nil }
                return v
            }()

            let calendarName: String? = {
                guard case .string(let v) = args["calendar_name"] else { return nil }
                return v
            }()

            do {
                let event = try await provider.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location,
                    notes: notes,
                    calendarName: calendarName
                )
                return CalendarTool.serialize(dict: event)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func updateEventHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "update_event") { arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            let title: String? = {
                guard case .string(let v) = args["title"] else { return nil }
                return v
            }()

            var startDate: Date? = nil
            if case .string(let rawStart) = args["start_date"] {
                guard let parsed = CalendarTool.parseDate(rawStart) else {
                    return .error("Invalid start_date: must be ISO 8601")
                }
                startDate = parsed
            }

            var endDate: Date? = nil
            if case .string(let rawEnd) = args["end_date"] {
                guard let parsed = CalendarTool.parseDate(rawEnd) else {
                    return .error("Invalid end_date: must be ISO 8601")
                }
                endDate = parsed
            }

            let location: String? = {
                guard case .string(let v) = args["location"] else { return nil }
                return v
            }()

            let notes: String? = {
                guard case .string(let v) = args["notes"] else { return nil }
                return v
            }()

            do {
                let event = try await provider.updateEvent(
                    id: id,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    notes: notes
                )
                return CalendarTool.serialize(dict: event)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func deleteEventHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "delete_event") { arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            let confirmation: Bool = {
                guard case .bool(let v) = args["confirmation"] else { return false }
                return v
            }()

            do {
                let result = try await provider.deleteEvent(id: id, confirmation: confirmation)
                return CalendarTool.serialize(dict: result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func checkAvailabilityHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "check_availability") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }

            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601")
            }

            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }

            do {
                let slots = try await provider.checkAvailability(startDate: startDate, endDate: endDate)
                return CalendarTool.serialize(array: slots)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func searchEventsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "search_events") { arguments in
            guard let args = arguments, case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }

            do {
                let events = try await provider.searchEvents(query: query)
                return CalendarTool.serialize(array: events)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func findConflictsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "find_conflicts") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }
            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601")
            }
            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }
            do {
                let conflicts = try await provider.findConflicts(startDate: startDate, endDate: endDate)
                return CalendarTool.serialize(array: conflicts)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func findGapsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "find_gaps") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }
            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601")
            }
            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }
            let minMinutes: Int? = {
                guard case .int(let v) = args["min_minutes"] else { return nil }
                return v
            }()
            do {
                let gaps = try await provider.findGaps(
                    startDate: startDate,
                    endDate: endDate,
                    minMinutes: minMinutes ?? 30
                )
                return CalendarTool.serialize(array: gaps)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func getCalendarStatsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "get_calendar_stats") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }
            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CalendarTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601")
            }
            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CalendarTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }
            do {
                let stats = try await provider.getCalendarStats(startDate: startDate, endDate: endDate)
                return CalendarTool.serialize(dict: stats)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func bulkDeclineEventsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "bulk_decline_events") { arguments in
            guard let args = arguments, case .array(let idValues) = args["ids"] else {
                return .error("Missing required parameter: ids")
            }
            let ids = idValues.compactMap { value -> String? in
                guard case .string(let s) = value else { return nil }
                return s
            }
            guard !ids.isEmpty else {
                return .error("ids array must not be empty")
            }
            guard case .bool(let confirmation) = args["confirmation"] else {
                return .error("Missing required parameter: confirmation")
            }
            guard confirmation else {
                return .error("confirmation must be true to bulk delete events")
            }
            do {
                let results = try await provider.bulkDeclineEvents(ids: ids, confirmation: confirmation)
                return CalendarTool.serialize(array: results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }
}
