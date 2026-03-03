import Foundation
@testable import MacOSLocalMCP

final class MockRemindersProvider: RemindersProviding {
    // MARK: - Call tracking
    var listReminderListsCalled = false
    var listRemindersCalled = false
    var createReminderCalled = false
    var updateReminderCalled = false
    var completeReminderCalled = false
    var searchRemindersCalled = false
    var moveReminderCalled = false
    var bulkMoveRemindersCalled = false

    // MARK: - Configurable results
    var listReminderListsResult: [[String: Any]] = []
    var listRemindersResult: [[String: Any]] = []
    var createReminderResult: [String: Any] = [:]
    var updateReminderResult: [String: Any] = [:]
    var completeReminderResult: [String: Any] = [:]
    var searchRemindersResult: [[String: Any]] = []
    var moveReminderResult: [String: Any] = [:]
    var bulkMoveRemindersResult: [[String: Any]] = []

    // MARK: - Configurable errors
    var listReminderListsError: Error?
    var listRemindersError: Error?
    var createReminderError: Error?
    var updateReminderError: Error?
    var completeReminderError: Error?
    var searchRemindersError: Error?
    var moveReminderError: Error?
    var bulkMoveRemindersError: Error?

    // MARK: - Captured arguments
    var lastListRemindersListName: String?
    var lastCreateReminderTitle: String?
    var lastUpdateReminderId: String?
    var lastCompleteReminderId: String?
    var lastSearchQuery: String?
    var lastMoveReminderId: String?
    var lastMoveReminderToList: String?
    var lastBulkMoveReminderIds: [String]?
    var lastBulkMoveReminderToList: String?

    // MARK: - Protocol conformance

    func listReminderLists() async throws -> [[String: Any]] {
        listReminderListsCalled = true
        if let error = listReminderListsError { throw error }
        return listReminderListsResult
    }

    func listReminders(listName: String?, dueDateStart: Date?, dueDateEnd: Date?, isCompleted: Bool?, priority: Int?) async throws -> [[String: Any]] {
        listRemindersCalled = true
        lastListRemindersListName = listName
        if let error = listRemindersError { throw error }
        return listRemindersResult
    }

    func createReminder(title: String, notes: String?, dueDate: Date?, priority: Int?, listName: String?) async throws -> [String: Any] {
        createReminderCalled = true
        lastCreateReminderTitle = title
        if let error = createReminderError { throw error }
        return createReminderResult
    }

    func updateReminder(id: String, title: String?, notes: String?, dueDate: Date?, priority: Int?, isCompleted: Bool?) async throws -> [String: Any] {
        updateReminderCalled = true
        lastUpdateReminderId = id
        if let error = updateReminderError { throw error }
        return updateReminderResult
    }

    func completeReminder(id: String) async throws -> [String: Any] {
        completeReminderCalled = true
        lastCompleteReminderId = id
        if let error = completeReminderError { throw error }
        return completeReminderResult
    }

    func searchReminders(query: String) async throws -> [[String: Any]] {
        searchRemindersCalled = true
        lastSearchQuery = query
        if let error = searchRemindersError { throw error }
        return searchRemindersResult
    }

    func moveReminder(id: String, toList: String) async throws -> [String: Any] {
        moveReminderCalled = true
        lastMoveReminderId = id
        lastMoveReminderToList = toList
        if let error = moveReminderError { throw error }
        return moveReminderResult
    }

    func bulkMoveReminders(ids: [String], toList: String) async throws -> [[String: Any]] {
        bulkMoveRemindersCalled = true
        lastBulkMoveReminderIds = ids
        lastBulkMoveReminderToList = toList
        if let error = bulkMoveRemindersError { throw error }
        return bulkMoveRemindersResult
    }
}
