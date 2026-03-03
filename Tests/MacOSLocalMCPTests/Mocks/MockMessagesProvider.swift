import Foundation
@testable import MacOSLocalMCP

final class MockMessagesProvider: MessagesProviding {
    var listConversationsCalled = false
    var readConversationCalled = false
    var sendMessageCalled = false
    var searchMessagesCalled = false

    var listConversationsResult: [[String: Any]] = []
    var readConversationResult: [[String: Any]] = []
    var sendMessageResult: [String: Any] = [:]
    var searchMessagesResult: [[String: Any]] = []

    var listConversationsError: Error?
    var readConversationError: Error?
    var sendMessageError: Error?
    var searchMessagesError: Error?

    var lastSendTo: String?
    var lastSendBody: String?

    func listConversations(count: Int) async throws -> [[String: Any]] {
        listConversationsCalled = true
        if let error = listConversationsError { throw error }
        return listConversationsResult
    }

    func readConversation(contactId: String, count: Int) async throws -> [[String: Any]] {
        readConversationCalled = true
        if let error = readConversationError { throw error }
        return readConversationResult
    }

    func sendMessage(to: String, body: String, confirmation: Bool) async throws -> [String: Any] {
        sendMessageCalled = true
        lastSendTo = to
        lastSendBody = body
        if let error = sendMessageError { throw error }
        return sendMessageResult
    }

    func searchMessages(query: String) async throws -> [[String: Any]] {
        searchMessagesCalled = true
        if let error = searchMessagesError { throw error }
        return searchMessagesResult
    }
}
