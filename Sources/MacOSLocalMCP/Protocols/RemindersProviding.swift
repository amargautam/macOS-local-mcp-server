import Foundation

/// Protocol for interacting with the macOS Reminders app via AppleScript/EventKit.
protocol RemindersProviding {
    func listReminderLists() async throws -> [[String: Any]]
    func listReminders(listName: String?, dueDateStart: Date?, dueDateEnd: Date?, isCompleted: Bool?, priority: Int?) async throws -> [[String: Any]]
    func createReminder(title: String, notes: String?, dueDate: Date?, priority: Int?, listName: String?) async throws -> [String: Any]
    func updateReminder(id: String, title: String?, notes: String?, dueDate: Date?, priority: Int?, isCompleted: Bool?) async throws -> [String: Any]
    func completeReminder(id: String) async throws -> [String: Any]
    func searchReminders(query: String) async throws -> [[String: Any]]
    func moveReminder(id: String, toList: String) async throws -> [String: Any]
    func bulkMoveReminders(ids: [String], toList: String) async throws -> [[String: Any]]
}
