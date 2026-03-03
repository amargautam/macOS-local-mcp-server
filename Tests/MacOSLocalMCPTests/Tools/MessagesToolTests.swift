import XCTest
@testable import MacOSLocalMCP

// MARK: - MessagesToolTests

final class MessagesToolTests: XCTestCase {

    var provider: MockMessagesProvider!
    var handlers: [MCPToolHandler]!

    override func setUp() {
        super.setUp()
        provider = MockMessagesProvider()
        let tool = MessagesTool(provider: provider)
        handlers = tool.createHandlers()
    }

    // MARK: - Helpers

    private func handler(named name: String) -> MCPToolHandler? {
        handlers.first { $0.toolName == name }
    }

    private func args(_ dict: [String: JSONValue]) -> [String: JSONValue]? {
        dict
    }

    // MARK: - Handler Registration

    func test_createHandlers_returns4Handlers() {
        XCTAssertEqual(handlers.count, 4)
    }

    func test_createHandlers_registersAllExpectedToolNames() {
        let names = handlers.map { $0.toolName }.sorted()
        XCTAssertEqual(names, [
            "list_conversations",
            "read_conversation",
            "search_messages",
            "send_message"
        ])
    }

    // MARK: - list_conversations: happy path

    func test_listConversations_withDefaultCount_callsProvider() async throws {
        provider.listConversationsResult = [
            ["contactName": "Alice", "lastMessage": "Hello!", "date": "2026-03-01"]
        ]

        let handler = try XCTUnwrap(handler(named: "list_conversations"))
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listConversationsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Alice"))
    }

    func test_listConversations_withCountArgument_passesCountToProvider() async throws {
        provider.listConversationsResult = []

        let handler = try XCTUnwrap(handler(named: "list_conversations"))
        _ = try await handler.handle(arguments: args(["count": .int(5)]))

        XCTAssertTrue(provider.listConversationsCalled)
    }

    func test_listConversations_withEmptyResult_returnsEmptyMessage() async throws {
        provider.listConversationsResult = []

        let handler = try XCTUnwrap(handler(named: "list_conversations"))
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func test_listConversations_withMultipleConversations_returnsAll() async throws {
        provider.listConversationsResult = [
            ["contactName": "Alice", "lastMessage": "Hi", "date": "2026-03-01"],
            ["contactName": "Bob", "lastMessage": "Hey", "date": "2026-03-01"]
        ]

        let handler = try XCTUnwrap(handler(named: "list_conversations"))
        let result = try await handler.handle(arguments: nil)

        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Alice"))
        XCTAssertTrue(text.contains("Bob"))
    }

    func test_listConversations_whenProviderThrows_returnsErrorResult() async throws {
        provider.listConversationsError = NSError(
            domain: "TestError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Messages access denied"]
        )

        let handler = try XCTUnwrap(handler(named: "list_conversations"))
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Messages access denied"))
    }

    // MARK: - read_conversation: happy path

    func test_readConversation_withContactId_callsProvider() async throws {
        provider.readConversationResult = [
            ["sender": "Alice", "body": "Hello!", "date": "2026-03-01"]
        ]

        let handler = try XCTUnwrap(handler(named: "read_conversation"))
        let result = try await handler.handle(arguments: args(["contact_id": .string("+15551234567")]))

        XCTAssertTrue(provider.readConversationCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Hello!"))
    }

    func test_readConversation_withCountArgument_passesCountToProvider() async throws {
        provider.readConversationResult = []

        let handler = try XCTUnwrap(handler(named: "read_conversation"))
        _ = try await handler.handle(arguments: args([
            "contact_id": .string("alice@example.com"),
            "count": .int(10)
        ]))

        XCTAssertTrue(provider.readConversationCalled)
    }

    func test_readConversation_missingContactId_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "read_conversation"))
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("contact_id"))
    }

    func test_readConversation_withEmptyResult_returnsEmptyMessage() async throws {
        provider.readConversationResult = []

        let handler = try XCTUnwrap(handler(named: "read_conversation"))
        let result = try await handler.handle(arguments: args(["contact_id": .string("+15551234567")]))

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func test_readConversation_whenProviderThrows_returnsErrorResult() async throws {
        provider.readConversationError = NSError(
            domain: "TestError",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Conversation not found"]
        )

        let handler = try XCTUnwrap(handler(named: "read_conversation"))
        let result = try await handler.handle(arguments: args(["contact_id": .string("+15551234567")]))

        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Conversation not found"))
    }

    // MARK: - send_message: happy path

    func test_sendMessage_withAllArgs_callsProvider() async throws {
        provider.sendMessageResult = ["status": "sent", "to": "+15551234567"]

        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "body": .string("Hello there!"),
            "confirmation": .bool(true)
        ]))

        XCTAssertTrue(provider.sendMessageCalled)
        XCTAssertEqual(provider.lastSendTo, "+15551234567")
        XCTAssertEqual(provider.lastSendBody, "Hello there!")
        XCTAssertFalse(result.isError ?? false)
    }

    func test_sendMessage_missingTo_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "body": .string("Hello"),
            "confirmation": .bool(true)
        ]))

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.sendMessageCalled)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("to"))
    }

    func test_sendMessage_missingBody_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "confirmation": .bool(true)
        ]))

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.sendMessageCalled)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("body"))
    }

    func test_sendMessage_whenProviderThrows_returnsErrorResult() async throws {
        provider.sendMessageError = NSError(
            domain: "TestError",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to send message"]
        )

        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "body": .string("Hi"),
            "confirmation": .bool(true)
        ]))

        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Failed to send message"))
    }

    func test_sendMessage_successResult_containsStatusInfo() async throws {
        provider.sendMessageResult = ["status": "sent", "to": "+15551234567"]

        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "body": .string("Hello"),
            "confirmation": .bool(true)
        ]))

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func test_sendMessage_withoutConfirmation_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "body": .string("Hello")
        ]))

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.sendMessageCalled)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("confirmation"))
    }

    func test_sendMessage_withConfirmationFalse_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "send_message"))
        let result = try await handler.handle(arguments: args([
            "to": .string("+15551234567"),
            "body": .string("Hello"),
            "confirmation": .bool(false)
        ]))

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.sendMessageCalled)
    }

    // MARK: - search_messages: happy path

    func test_searchMessages_withQuery_callsProvider() async throws {
        provider.searchMessagesResult = [
            ["sender": "Alice", "body": "meeting tomorrow", "date": "2026-03-01"]
        ]

        let handler = try XCTUnwrap(handler(named: "search_messages"))
        let result = try await handler.handle(arguments: args(["query": .string("meeting")]))

        XCTAssertTrue(provider.searchMessagesCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("meeting"))
    }

    func test_searchMessages_missingQuery_returnsError() async throws {
        let handler = try XCTUnwrap(handler(named: "search_messages"))
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.searchMessagesCalled)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("query"))
    }

    func test_searchMessages_withEmptyResult_returnsEmptyMessage() async throws {
        provider.searchMessagesResult = []

        let handler = try XCTUnwrap(handler(named: "search_messages"))
        let result = try await handler.handle(arguments: args(["query": .string("nothing")]))

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func test_searchMessages_withMultipleResults_returnsAll() async throws {
        provider.searchMessagesResult = [
            ["sender": "Alice", "body": "lunch meeting", "date": "2026-03-01"],
            ["sender": "Bob", "body": "team meeting", "date": "2026-03-02"]
        ]

        let handler = try XCTUnwrap(handler(named: "search_messages"))
        let result = try await handler.handle(arguments: args(["query": .string("meeting")]))

        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("lunch meeting"))
        XCTAssertTrue(text.contains("team meeting"))
    }

    func test_searchMessages_whenProviderThrows_returnsErrorResult() async throws {
        provider.searchMessagesError = NSError(
            domain: "TestError",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Search failed"]
        )

        let handler = try XCTUnwrap(handler(named: "search_messages"))
        let result = try await handler.handle(arguments: args(["query": .string("test")]))

        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Search failed"))
    }
}
