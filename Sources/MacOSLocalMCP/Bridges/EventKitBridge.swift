import Foundation
import EventKit

/// Concrete bridge that implements RemindersProviding and CalendarProviding using EventKit.
/// All EventKit operations are performed on a background thread via async/await.
final class EventKitBridge: RemindersProviding, CalendarProviding {

    private let remindersStore: EKEventStore
    private let calendarStore: EKEventStore

    /// Using separate stores is not required; a single store can handle both.
    /// We expose a shared instance for convenience.
    init(eventStore: EKEventStore = EKEventStore()) {
        self.remindersStore = eventStore
        self.calendarStore = eventStore
    }

    // MARK: - Permission helpers

    private func requestRemindersAccess() async throws {
        if #available(macOS 14.0, *) {
            try await remindersStore.requestFullAccessToReminders()
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                remindersStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if !granted {
                        continuation.resume(throwing: EventKitError.accessDenied("Reminders access denied"))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func requestCalendarAccess() async throws {
        if #available(macOS 14.0, *) {
            try await calendarStore.requestFullAccessToEvents()
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                calendarStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if !granted {
                        continuation.resume(throwing: EventKitError.accessDenied("Calendar access denied"))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    // MARK: - RemindersProviding

    func listReminderLists() async throws -> [[String: Any]] {
        try await requestRemindersAccess()
        let calendars = remindersStore.calendars(for: .reminder)
        return calendars.map { calendar in
            [
                "id": calendar.calendarIdentifier,
                "name": calendar.title,
                "color": colorHex(calendar.cgColor)
            ]
        }
    }

    func listReminders(
        listName: String?,
        dueDateStart: Date?,
        dueDateEnd: Date?,
        isCompleted: Bool?,
        priority: Int?
    ) async throws -> [[String: Any]] {
        try await requestRemindersAccess()

        // Find the target calendars
        let allCalendars = remindersStore.calendars(for: .reminder)
        let targetCalendars: [EKCalendar]
        if let listName = listName {
            targetCalendars = allCalendars.filter { $0.title == listName }
        } else {
            targetCalendars = allCalendars
        }

        // Build predicate
        let predicate: NSPredicate
        if let completed = isCompleted {
            predicate = remindersStore.predicateForReminders(in: targetCalendars.isEmpty ? nil : targetCalendars)
            _ = completed // will filter below
        } else {
            predicate = remindersStore.predicateForReminders(in: targetCalendars.isEmpty ? nil : targetCalendars)
        }

        let reminders: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            remindersStore.fetchReminders(matching: predicate) { fetched in
                continuation.resume(returning: fetched ?? [])
            }
        }

        // Filter client-side
        var filtered = reminders

        if let completed = isCompleted {
            filtered = filtered.filter { $0.isCompleted == completed }
        }

        if let start = dueDateStart {
            filtered = filtered.filter { reminder in
                guard let due = reminder.dueDateComponents?.date else { return false }
                return due >= start
            }
        }

        if let end = dueDateEnd {
            filtered = filtered.filter { reminder in
                guard let due = reminder.dueDateComponents?.date else { return false }
                return due <= end
            }
        }

        if let priority = priority {
            filtered = filtered.filter { $0.priority == priority }
        }

        return filtered.map { reminderToDict($0) }
    }

    func createReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        priority: Int?,
        listName: String?
    ) async throws -> [String: Any] {
        try await requestRemindersAccess()

        let reminder = EKReminder(eventStore: remindersStore)
        reminder.title = title
        reminder.notes = notes

        if let dueDate = dueDate {
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
            components.timeZone = TimeZone.current
            reminder.dueDateComponents = components
        }

        if let priority = priority {
            reminder.priority = priority
        }

        // Find or use default calendar
        if let listName = listName {
            let calendars = remindersStore.calendars(for: .reminder)
            if let calendar = calendars.first(where: { $0.title == listName }) {
                reminder.calendar = calendar
            } else {
                reminder.calendar = remindersStore.defaultCalendarForNewReminders()
            }
        } else {
            reminder.calendar = remindersStore.defaultCalendarForNewReminders()
        }

        try remindersStore.save(reminder, commit: true)
        return reminderToDict(reminder)
    }

    func updateReminder(
        id: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        priority: Int?,
        isCompleted: Bool?
    ) async throws -> [String: Any] {
        try await requestRemindersAccess()

        guard let reminder = remindersStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.notFound("Reminder not found: \(id)")
        }

        if let title = title { reminder.title = title }
        if let notes = notes { reminder.notes = notes }

        if let dueDate = dueDate {
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
            components.timeZone = TimeZone.current
            reminder.dueDateComponents = components
        }

        if let priority = priority { reminder.priority = priority }
        if let isCompleted = isCompleted { reminder.isCompleted = isCompleted }

        try remindersStore.save(reminder, commit: true)
        return reminderToDict(reminder)
    }

    func completeReminder(id: String) async throws -> [String: Any] {
        try await requestRemindersAccess()

        guard let reminder = remindersStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.notFound("Reminder not found: \(id)")
        }

        reminder.isCompleted = true
        reminder.completionDate = Date()
        try remindersStore.save(reminder, commit: true)
        return reminderToDict(reminder)
    }

    func searchReminders(query: String) async throws -> [[String: Any]] {
        try await requestRemindersAccess()

        let predicate = remindersStore.predicateForReminders(in: nil)
        let allReminders: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            remindersStore.fetchReminders(matching: predicate) { fetched in
                continuation.resume(returning: fetched ?? [])
            }
        }

        let lowercased = query.lowercased()
        let matched = allReminders.filter { reminder in
            let titleMatch = reminder.title?.lowercased().contains(lowercased) ?? false
            let notesMatch = reminder.notes?.lowercased().contains(lowercased) ?? false
            return titleMatch || notesMatch
        }

        return matched.map { reminderToDict($0) }
    }

    func moveReminder(id: String, toList: String) async throws -> [String: Any] {
        try await requestRemindersAccess()

        guard let reminder = remindersStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.notFound("Reminder not found: \(id)")
        }

        let calendars = remindersStore.calendars(for: .reminder)
        guard let targetCalendar = calendars.first(where: { $0.title == toList }) else {
            throw EventKitError.notFound("Reminder list not found: \(toList)")
        }

        reminder.calendar = targetCalendar
        try remindersStore.save(reminder, commit: true)
        return reminderToDict(reminder)
    }

    func bulkMoveReminders(ids: [String], toList: String) async throws -> [[String: Any]] {
        try await requestRemindersAccess()

        let calendars = remindersStore.calendars(for: .reminder)
        guard let targetCalendar = calendars.first(where: { $0.title == toList }) else {
            throw EventKitError.notFound("Reminder list not found: \(toList)")
        }

        var results: [[String: Any]] = []
        for id in ids {
            guard let reminder = remindersStore.calendarItem(withIdentifier: id) as? EKReminder else {
                results.append(["id": id, "error": "Reminder not found"])
                continue
            }
            reminder.calendar = targetCalendar
            do {
                try remindersStore.save(reminder, commit: true)
                results.append(reminderToDict(reminder))
            } catch {
                results.append(["id": id, "error": error.localizedDescription])
            }
        }
        return results
    }

    // MARK: - CalendarProviding

    func listCalendars() async throws -> [[String: Any]] {
        try await requestCalendarAccess()
        let calendars = calendarStore.calendars(for: .event)
        return calendars.map { calendar in
            [
                "id": calendar.calendarIdentifier,
                "name": calendar.title,
                "color": colorHex(calendar.cgColor),
                "isSubscribed": calendar.isSubscribed,
                "allowsContentModifications": calendar.allowsContentModifications
            ]
        }
    }

    func listEvents(startDate: Date, endDate: Date, calendarName: String?) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        let allCalendars = calendarStore.calendars(for: .event)
        let targetCalendars: [EKCalendar]
        if let calendarName = calendarName {
            targetCalendars = allCalendars.filter { $0.title == calendarName }
        } else {
            targetCalendars = allCalendars
        }

        let predicate = calendarStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: targetCalendars.isEmpty ? nil : targetCalendars
        )

        let events = calendarStore.events(matching: predicate)
        return events.map { eventToDict($0) }
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarName: String?
    ) async throws -> [String: Any] {
        try await requestCalendarAccess()

        let event = EKEvent(eventStore: calendarStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes

        if let calendarName = calendarName {
            let calendars = calendarStore.calendars(for: .event)
            if let calendar = calendars.first(where: { $0.title == calendarName }) {
                event.calendar = calendar
            } else {
                event.calendar = calendarStore.defaultCalendarForNewEvents
            }
        } else {
            event.calendar = calendarStore.defaultCalendarForNewEvents
        }

        try calendarStore.save(event, span: .thisEvent, commit: true)
        return eventToDict(event)
    }

    func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws -> [String: Any] {
        try await requestCalendarAccess()

        guard let event = calendarStore.event(withIdentifier: id) else {
            throw EventKitError.notFound("Event not found: \(id)")
        }

        if let title = title { event.title = title }
        if let startDate = startDate { event.startDate = startDate }
        if let endDate = endDate { event.endDate = endDate }
        if let location = location { event.location = location }
        if let notes = notes { event.notes = notes }

        try calendarStore.save(event, span: .thisEvent, commit: true)
        return eventToDict(event)
    }

    func deleteEvent(id: String, confirmation: Bool) async throws -> [String: Any] {
        try await requestCalendarAccess()

        guard let event = calendarStore.event(withIdentifier: id) else {
            throw EventKitError.notFound("Event not found: \(id)")
        }

        let result = eventToDict(event)
        try calendarStore.remove(event, span: .thisEvent, commit: true)
        var dict = result
        dict["deleted"] = true
        return dict
    }

    func checkAvailability(startDate: Date, endDate: Date) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        let predicate = calendarStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = calendarStore.events(matching: predicate)
        return events.map { event in
            [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start": ISO8601DateFormatter().string(from: event.startDate),
                "end": ISO8601DateFormatter().string(from: event.endDate),
                "isFree": event.availability == .free
            ]
        }
    }

    func searchEvents(query: String) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        let predicate = calendarStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: nil
        )

        let lowercased = query.lowercased()
        let allEvents = calendarStore.events(matching: predicate)
        let matched = allEvents.filter { event in
            let titleMatch = event.title?.lowercased().contains(lowercased) ?? false
            let notesMatch = event.notes?.lowercased().contains(lowercased) ?? false
            let locationMatch = event.location?.lowercased().contains(lowercased) ?? false
            return titleMatch || notesMatch || locationMatch
        }

        return matched.map { eventToDict($0) }
    }

    func findConflicts(startDate: Date, endDate: Date) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        let predicate = calendarStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = calendarStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let formatter = ISO8601DateFormatter()
        var conflicts: [[String: Any]] = []

        for i in 0..<events.count {
            for j in (i + 1)..<events.count {
                let a = events[i]
                let b = events[j]
                // Two events overlap when one starts before the other ends
                guard a.startDate < b.endDate && b.startDate < a.endDate else { continue }
                let overlapStart = max(a.startDate, b.startDate)
                let overlapEnd = min(a.endDate, b.endDate)
                conflicts.append([
                    "event1": a.eventIdentifier ?? "",
                    "event1Title": a.title ?? "",
                    "event2": b.eventIdentifier ?? "",
                    "event2Title": b.title ?? "",
                    "overlapStart": formatter.string(from: overlapStart),
                    "overlapEnd": formatter.string(from: overlapEnd)
                ])
            }
        }

        return conflicts
    }

    func findGaps(startDate: Date, endDate: Date, minMinutes: Int?) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        let predicate = calendarStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = calendarStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let minDuration = TimeInterval((minMinutes ?? 30) * 60)
        let formatter = ISO8601DateFormatter()
        var gaps: [[String: Any]] = []
        var cursor = startDate

        for event in events {
            guard let eventStart = event.startDate, let eventEnd = event.endDate else { continue }
            let gapEnd = eventStart
            if gapEnd > cursor {
                let duration = gapEnd.timeIntervalSince(cursor)
                if duration >= minDuration {
                    gaps.append([
                        "start": formatter.string(from: cursor),
                        "end": formatter.string(from: gapEnd),
                        "minutes": Int(duration / 60)
                    ])
                }
            }
            // Advance cursor past this event (handle overlapping events)
            if eventEnd > cursor {
                cursor = eventEnd
            }
        }

        // Check for gap after last event
        if endDate > cursor {
            let duration = endDate.timeIntervalSince(cursor)
            if duration >= minDuration {
                gaps.append([
                    "start": formatter.string(from: cursor),
                    "end": formatter.string(from: endDate),
                    "minutes": Int(duration / 60)
                ])
            }
        }

        return gaps
    }

    func getCalendarStats(startDate: Date, endDate: Date) async throws -> [String: Any] {
        try await requestCalendarAccess()

        let predicate = calendarStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        let events = calendarStore.events(matching: predicate)

        let totalEvents = events.count
        let totalHours = events.reduce(0.0) { sum, event in
            sum + event.endDate.timeIntervalSince(event.startDate) / 3600.0
        }

        // Find busiest day
        var dayEventCounts: [String: Int] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        for event in events {
            let day = dayFormatter.string(from: event.startDate)
            dayEventCounts[day, default: 0] += 1
        }
        let busiestDay = dayEventCounts.max(by: { $0.value < $1.value })?.key ?? ""

        // Count per calendar
        var eventsPerCalendar: [String: Int] = [:]
        for event in events {
            let calName = event.calendar?.title ?? "Unknown"
            eventsPerCalendar[calName, default: 0] += 1
        }

        return [
            "totalEvents": totalEvents,
            "totalHours": totalHours,
            "busiestDay": busiestDay,
            "eventsPerCalendar": eventsPerCalendar
        ]
    }

    func bulkDeclineEvents(ids: [String], confirmation: Bool) async throws -> [[String: Any]] {
        try await requestCalendarAccess()

        var results: [[String: Any]] = []
        for id in ids {
            guard let event = calendarStore.event(withIdentifier: id) else {
                results.append(["id": id, "error": "Event not found"])
                continue
            }
            let eventDict = eventToDict(event)
            do {
                try calendarStore.remove(event, span: .thisEvent, commit: true)
                var result = eventDict
                result["deleted"] = true
                results.append(result)
            } catch {
                results.append(["id": id, "error": error.localizedDescription])
            }
        }
        return results
    }

    // MARK: - Serialization helpers

    private func reminderToDict(_ reminder: EKReminder) -> [String: Any] {
        var dict: [String: Any] = [
            "id": reminder.calendarItemIdentifier,
            "title": reminder.title ?? "",
            "isCompleted": reminder.isCompleted,
            "priority": reminder.priority,
            "listName": reminder.calendar?.title ?? ""
        ]
        if let notes = reminder.notes { dict["notes"] = notes }
        if let dueComponents = reminder.dueDateComponents,
           let dueDate = Calendar.current.date(from: dueComponents) {
            dict["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }
        if let completionDate = reminder.completionDate {
            dict["completionDate"] = ISO8601DateFormatter().string(from: completionDate)
        }
        return dict
    }

    private func eventToDict(_ event: EKEvent) -> [String: Any] {
        var dict: [String: Any] = [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "",
            "startDate": ISO8601DateFormatter().string(from: event.startDate),
            "endDate": ISO8601DateFormatter().string(from: event.endDate),
            "isAllDay": event.isAllDay,
            "calendarName": event.calendar?.title ?? ""
        ]
        if let location = event.location { dict["location"] = location }
        if let notes = event.notes { dict["notes"] = notes }
        return dict
    }

    private func colorHex(_ cgColor: CGColor?) -> String {
        guard let color = cgColor,
              let components = color.components,
              components.count >= 3 else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - EventKitError

enum EventKitError: Error, LocalizedError {
    case accessDenied(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied(let message): return message
        case .notFound(let message): return message
        }
    }
}
