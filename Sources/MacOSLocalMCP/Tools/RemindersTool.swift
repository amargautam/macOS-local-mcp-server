import Foundation

/// Provides MCPToolHandler instances for all Reminders-related tools.
final class RemindersTool {
    private let provider: RemindersProviding

    init(provider: RemindersProviding) {
        self.provider = provider
    }

    /// Returns all 8 handler objects for the Reminders module.
    func createHandlers() -> [MCPToolHandler] {
        [
            listReminderListsHandler(),
            listRemindersHandler(),
            createReminderHandler(),
            updateReminderHandler(),
            completeReminderHandler(),
            searchRemindersHandler(),
            moveReminderHandler(),
            bulkMoveRemindersHandler()
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
    // Each handler captures the provider strongly so it stays alive independently of RemindersTool.

    private func listReminderListsHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "list_reminder_lists") { _ in
            do {
                let lists = try await provider.listReminderLists()
                return RemindersTool.serialize(array: lists)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listRemindersHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "list_reminders") { arguments in
            // Optional list_name
            let listName: String? = arguments.flatMap {
                guard case .string(let v) = $0["list_name"] else { return nil }
                return v
            }

            // Optional due_date_start
            var dueDateStart: Date? = nil
            if let rawStart = arguments.flatMap({ (args: [String: JSONValue]) -> String? in
                guard case .string(let v) = args["due_date_start"] else { return nil }
                return v
            }) {
                guard let parsed = RemindersTool.parseDate(rawStart) else {
                    return .error("Invalid due_date_start: must be ISO 8601 (e.g. 2026-03-01T00:00:00Z)")
                }
                dueDateStart = parsed
            }

            // Optional due_date_end
            var dueDateEnd: Date? = nil
            if let rawEnd = arguments.flatMap({ (args: [String: JSONValue]) -> String? in
                guard case .string(let v) = args["due_date_end"] else { return nil }
                return v
            }) {
                guard let parsed = RemindersTool.parseDate(rawEnd) else {
                    return .error("Invalid due_date_end: must be ISO 8601 (e.g. 2026-03-31T23:59:59Z)")
                }
                dueDateEnd = parsed
            }

            // Optional is_completed
            let isCompleted: Bool? = arguments.flatMap {
                guard case .bool(let v) = $0["is_completed"] else { return nil }
                return v
            }

            // Optional priority
            let priority: Int? = arguments.flatMap {
                guard case .int(let v) = $0["priority"] else { return nil }
                return v
            }

            do {
                let reminders = try await provider.listReminders(
                    listName: listName,
                    dueDateStart: dueDateStart,
                    dueDateEnd: dueDateEnd,
                    isCompleted: isCompleted,
                    priority: priority
                )
                return RemindersTool.serialize(array: reminders)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func createReminderHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "create_reminder") { arguments in
            guard let args = arguments, case .string(let title) = args["title"] else {
                return .error("Missing required parameter: title")
            }

            let notes: String? = {
                guard case .string(let v) = args["notes"] else { return nil }
                return v
            }()

            var dueDate: Date? = nil
            if case .string(let rawDate) = args["due_date"] {
                guard let parsed = RemindersTool.parseDate(rawDate) else {
                    return .error("Invalid due_date: must be ISO 8601 (e.g. 2026-03-15T10:00:00Z)")
                }
                dueDate = parsed
            }

            let priority: Int? = {
                guard case .int(let v) = args["priority"] else { return nil }
                return v
            }()

            let listName: String? = {
                guard case .string(let v) = args["list_name"] else { return nil }
                return v
            }()

            do {
                let reminder = try await provider.createReminder(
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    priority: priority,
                    listName: listName
                )
                return RemindersTool.serialize(dict: reminder)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func updateReminderHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "update_reminder") { arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            let title: String? = {
                guard case .string(let v) = args["title"] else { return nil }
                return v
            }()

            let notes: String? = {
                guard case .string(let v) = args["notes"] else { return nil }
                return v
            }()

            var dueDate: Date? = nil
            if case .string(let rawDate) = args["due_date"] {
                guard let parsed = RemindersTool.parseDate(rawDate) else {
                    return .error("Invalid due_date: must be ISO 8601")
                }
                dueDate = parsed
            }

            let priority: Int? = {
                guard case .int(let v) = args["priority"] else { return nil }
                return v
            }()

            let isCompleted: Bool? = {
                guard case .bool(let v) = args["is_completed"] else { return nil }
                return v
            }()

            do {
                let reminder = try await provider.updateReminder(
                    id: id,
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    priority: priority,
                    isCompleted: isCompleted
                )
                return RemindersTool.serialize(dict: reminder)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func completeReminderHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "complete_reminder") { arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            do {
                let reminder = try await provider.completeReminder(id: id)
                return RemindersTool.serialize(dict: reminder)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func searchRemindersHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "search_reminders") { arguments in
            guard let args = arguments, case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }

            do {
                let reminders = try await provider.searchReminders(query: query)
                return RemindersTool.serialize(array: reminders)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func moveReminderHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "move_reminder") { arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }
            guard case .string(let toList) = args["to_list"] else {
                return .error("Missing required parameter: to_list")
            }
            do {
                let result = try await provider.moveReminder(id: id, toList: toList)
                return RemindersTool.serialize(dict: result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func bulkMoveRemindersHandler() -> MCPToolHandler {
        let provider = self.provider
        return ClosureToolHandler(toolName: "bulk_move_reminders") { arguments in
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
            guard case .string(let toList) = args["to_list"] else {
                return .error("Missing required parameter: to_list")
            }
            do {
                let results = try await provider.bulkMoveReminders(ids: ids, toList: toList)
                return RemindersTool.serialize(array: results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }
}
