import XCTest
@testable import MacOSLocalMCP

final class RemindersToolTests: XCTestCase {

    // MARK: - Helpers

    private func makeHandlers(provider: MockRemindersProvider) -> [String: MCPToolHandler] {
        let tool = RemindersTool(provider: provider)
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

    // MARK: - list_reminder_lists

    func test_listReminderLists_happyPath_returnsJSON() async throws {
        let provider = MockRemindersProvider()
        provider.listReminderListsResult = [
            ["id": "list-1", "name": "Reminders"],
            ["id": "list-2", "name": "Work"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminder_lists"])

        let result = try await call(handler)

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listReminderListsCalled)
        let body = text(result)
        XCTAssertTrue(body.contains("list-1"))
        XCTAssertTrue(body.contains("Reminders"))
    }

    func test_listReminderLists_emptyResult_returnsEmptyArray() async throws {
        let provider = MockRemindersProvider()
        provider.listReminderListsResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminder_lists"])

        let result = try await call(handler)

        XCTAssertFalse(isError(result))
        XCTAssertEqual(text(result), "[]")
    }

    func test_listReminderLists_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.listReminderListsError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminder_lists"])

        let result = try await call(handler)

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Access denied"))
    }

    // MARK: - list_reminders

    func test_listReminders_happyPath_noFilters() async throws {
        let provider = MockRemindersProvider()
        provider.listRemindersResult = [
            ["id": "r-1", "title": "Buy groceries", "isCompleted": false]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        let result = try await call(handler, args: [:])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listRemindersCalled)
        XCTAssertTrue(text(result).contains("Buy groceries"))
    }

    func test_listReminders_withListNameFilter_passesThrough() async throws {
        let provider = MockRemindersProvider()
        provider.listRemindersResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        _ = try await call(handler, args: ["list_name": .string("Work")])

        XCTAssertEqual(provider.lastListRemindersListName, "Work")
    }

    func test_listReminders_withDueDateRange_parsesISO8601() async throws {
        let provider = MockRemindersProvider()
        provider.listRemindersResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        let result = try await call(handler, args: [
            "due_date_start": .string("2026-03-01T00:00:00Z"),
            "due_date_end": .string("2026-03-31T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.listRemindersCalled)
    }

    func test_listReminders_withInvalidDate_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        let result = try await call(handler, args: [
            "due_date_start": .string("not-a-date")
        ])

        XCTAssertTrue(isError(result))
    }

    func test_listReminders_withCompletedFilter_passesThrough() async throws {
        let provider = MockRemindersProvider()
        provider.listRemindersResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        _ = try await call(handler, args: ["is_completed": .bool(true)])

        XCTAssertTrue(provider.listRemindersCalled)
    }

    func test_listReminders_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.listRemindersError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "DB error"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_reminders"])

        let result = try await call(handler)

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("DB error"))
    }

    // MARK: - create_reminder

    func test_createReminder_happyPath_returnsCreatedReminder() async throws {
        let provider = MockRemindersProvider()
        provider.createReminderResult = ["id": "new-1", "title": "Buy milk"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_reminder"])

        let result = try await call(handler, args: ["title": .string("Buy milk")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.createReminderCalled)
        XCTAssertEqual(provider.lastCreateReminderTitle, "Buy milk")
        XCTAssertTrue(text(result).contains("Buy milk"))
    }

    func test_createReminder_missingTitle_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_reminder"])

        let result = try await call(handler, args: [:])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.createReminderCalled)
        XCTAssertTrue(text(result).lowercased().contains("title"))
    }

    func test_createReminder_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_reminder"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.createReminderCalled)
    }

    func test_createReminder_withOptionalFields_passesThrough() async throws {
        let provider = MockRemindersProvider()
        provider.createReminderResult = ["id": "new-2", "title": "Task"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_reminder"])

        let result = try await call(handler, args: [
            "title": .string("Task"),
            "notes": .string("Some notes"),
            "due_date": .string("2026-03-15T10:00:00Z"),
            "priority": .int(1),
            "list_name": .string("Work")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.createReminderCalled)
    }

    func test_createReminder_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.createReminderError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_reminder"])

        let result = try await call(handler, args: ["title": .string("Task")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Save failed"))
    }

    // MARK: - update_reminder

    func test_updateReminder_happyPath_returnsUpdated() async throws {
        let provider = MockRemindersProvider()
        provider.updateReminderResult = ["id": "r-1", "title": "Updated title"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_reminder"])

        let result = try await call(handler, args: [
            "id": .string("r-1"),
            "title": .string("Updated title")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.updateReminderCalled)
        XCTAssertEqual(provider.lastUpdateReminderId, "r-1")
        XCTAssertTrue(text(result).contains("Updated title"))
    }

    func test_updateReminder_missingId_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_reminder"])

        let result = try await call(handler, args: ["title": .string("No ID")])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.updateReminderCalled)
    }

    func test_updateReminder_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_reminder"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.updateReminderCalled)
    }

    func test_updateReminder_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.updateReminderError = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Update failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["update_reminder"])

        let result = try await call(handler, args: ["id": .string("r-1")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Update failed"))
    }

    // MARK: - complete_reminder

    func test_completeReminder_happyPath_returnsCompleted() async throws {
        let provider = MockRemindersProvider()
        provider.completeReminderResult = ["id": "r-1", "isCompleted": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["complete_reminder"])

        let result = try await call(handler, args: ["id": .string("r-1")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.completeReminderCalled)
        XCTAssertEqual(provider.lastCompleteReminderId, "r-1")
    }

    func test_completeReminder_missingId_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["complete_reminder"])

        let result = try await call(handler, args: [:])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.completeReminderCalled)
    }

    func test_completeReminder_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["complete_reminder"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.completeReminderCalled)
    }

    func test_completeReminder_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.completeReminderError = NSError(domain: "test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Complete failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["complete_reminder"])

        let result = try await call(handler, args: ["id": .string("r-1")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Complete failed"))
    }

    // MARK: - search_reminders

    func test_searchReminders_happyPath_returnsMatches() async throws {
        let provider = MockRemindersProvider()
        provider.searchRemindersResult = [
            ["id": "r-2", "title": "Call dentist"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_reminders"])

        let result = try await call(handler, args: ["query": .string("dentist")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.searchRemindersCalled)
        XCTAssertEqual(provider.lastSearchQuery, "dentist")
        XCTAssertTrue(text(result).contains("Call dentist"))
    }

    func test_searchReminders_missingQuery_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_reminders"])

        let result = try await call(handler, args: [:])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.searchRemindersCalled)
    }

    func test_searchReminders_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_reminders"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.searchRemindersCalled)
    }

    func test_searchReminders_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.searchRemindersError = NSError(domain: "test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_reminders"])

        let result = try await call(handler, args: ["query": .string("test")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Search failed"))
    }

    // MARK: - move_reminder

    func test_moveReminder_happyPath_returnsMovedReminder() async throws {
        let provider = MockRemindersProvider()
        provider.moveReminderResult = ["id": "r-1", "listName": "Work"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_reminder"])

        let result = try await call(handler, args: [
            "id": .string("r-1"),
            "to_list": .string("Work")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.moveReminderCalled)
        XCTAssertEqual(provider.lastMoveReminderId, "r-1")
        XCTAssertEqual(provider.lastMoveReminderToList, "Work")
        XCTAssertTrue(text(result).contains("Work"))
    }

    func test_moveReminder_missingId_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_reminder"])

        let result = try await call(handler, args: ["to_list": .string("Work")])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.moveReminderCalled)
        XCTAssertTrue(text(result).lowercased().contains("id"))
    }

    func test_moveReminder_missingToList_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_reminder"])

        let result = try await call(handler, args: ["id": .string("r-1")])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.moveReminderCalled)
        XCTAssertTrue(text(result).lowercased().contains("to_list"))
    }

    func test_moveReminder_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_reminder"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.moveReminderCalled)
    }

    func test_moveReminder_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.moveReminderError = NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "List not found"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_reminder"])

        let result = try await call(handler, args: [
            "id": .string("r-1"),
            "to_list": .string("NonExistent")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("List not found"))
    }

    // MARK: - bulk_move_reminders

    func test_bulkMoveReminders_happyPath_returnsArray() async throws {
        let provider = MockRemindersProvider()
        provider.bulkMoveRemindersResult = [
            ["id": "r-1", "listName": "Work"],
            ["id": "r-2", "listName": "Work"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: [
            "ids": .array([.string("r-1"), .string("r-2")]),
            "to_list": .string("Work")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(provider.bulkMoveRemindersCalled)
        XCTAssertEqual(provider.lastBulkMoveReminderIds, ["r-1", "r-2"])
        XCTAssertEqual(provider.lastBulkMoveReminderToList, "Work")
        XCTAssertTrue(text(result).contains("r-1"))
        XCTAssertTrue(text(result).contains("r-2"))
    }

    func test_bulkMoveReminders_missingIds_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: ["to_list": .string("Work")])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkMoveRemindersCalled)
        XCTAssertTrue(text(result).lowercased().contains("ids"))
    }

    func test_bulkMoveReminders_missingToList_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: [
            "ids": .array([.string("r-1")])
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkMoveRemindersCalled)
        XCTAssertTrue(text(result).lowercased().contains("to_list"))
    }

    func test_bulkMoveReminders_emptyIds_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: [
            "ids": .array([]),
            "to_list": .string("Work")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkMoveRemindersCalled)
    }

    func test_bulkMoveReminders_nilArguments_returnsError() async throws {
        let provider = MockRemindersProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
        XCTAssertFalse(provider.bulkMoveRemindersCalled)
    }

    func test_bulkMoveReminders_providerError_returnsError() async throws {
        let provider = MockRemindersProvider()
        provider.bulkMoveRemindersError = NSError(domain: "test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Bulk move failed"])
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_move_reminders"])

        let result = try await call(handler, args: [
            "ids": .array([.string("r-1")]),
            "to_list": .string("Work")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Bulk move failed"))
    }

    // MARK: - Handler registration

    func test_createHandlers_registersAllEightTools() {
        let provider = MockRemindersProvider()
        let tool = RemindersTool(provider: provider)
        let handlers = tool.createHandlers()

        let names = Set(handlers.map { $0.toolName })
        XCTAssertEqual(names.count, 8)
        XCTAssertTrue(names.contains("list_reminder_lists"))
        XCTAssertTrue(names.contains("list_reminders"))
        XCTAssertTrue(names.contains("create_reminder"))
        XCTAssertTrue(names.contains("update_reminder"))
        XCTAssertTrue(names.contains("complete_reminder"))
        XCTAssertTrue(names.contains("search_reminders"))
        XCTAssertTrue(names.contains("move_reminder"))
        XCTAssertTrue(names.contains("bulk_move_reminders"))
    }
}
