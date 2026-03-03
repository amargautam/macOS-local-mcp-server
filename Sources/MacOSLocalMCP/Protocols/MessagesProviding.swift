import Foundation

/// Protocol for interacting with the macOS Messages app via AppleScript.
protocol MessagesProviding {
    func listConversations(count: Int) async throws -> [[String: Any]]
    func readConversation(contactId: String, count: Int) async throws -> [[String: Any]]
    func sendMessage(to: String, body: String, confirmation: Bool) async throws -> [String: Any]
    func searchMessages(query: String) async throws -> [[String: Any]]
}
