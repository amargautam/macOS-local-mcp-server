import XCTest
@testable import MacOSLocalMCP

// MARK: - MessagesBridgeTests

final class MessagesBridgeTests: XCTestCase {

    var executor: MockScriptExecutor!
    var bridge: MessagesBridge!

    override func setUp() {
        super.setUp()
        executor = MockScriptExecutor()
        bridge = MessagesBridge(executor: executor)
    }

    // MARK: - listConversations Script Generation

    func test_listConversationsScript_containsSqlite() {
        let script = bridge.listConversationsScript(count: 10)
        XCTAssertTrue(script.contains("sqlite3"))
    }

    func test_listConversationsScript_containsCount() {
        let script = bridge.listConversationsScript(count: 5)
        XCTAssertTrue(script.contains("5"))
    }

    func test_listConversationsScript_containsChatDb() {
        let script = bridge.listConversationsScript(count: 10)
        XCTAssertTrue(script.contains("chat.db"))
    }

    func test_listConversationsScript_containsChatTable() {
        let script = bridge.listConversationsScript(count: 10)
        XCTAssertTrue(script.contains("chat"))
    }

    func test_listConversationsScript_containsMessageTable() {
        let script = bridge.listConversationsScript(count: 10)
        XCTAssertTrue(script.contains("message"))
    }

    func test_listConversationsScript_containsDelimiter() {
        let script = bridge.listConversationsScript(count: 10)
        XCTAssertTrue(script.contains("|||"))
    }

    // MARK: - readConversation Script Generation

    func test_readConversationScript_containsSqlite() {
        let script = bridge.readConversationScript(contactId: "+15551234567", count: 20)
        XCTAssertTrue(script.contains("sqlite3"))
    }

    func test_readConversationScript_containsContactId() {
        let script = bridge.readConversationScript(contactId: "+15551234567", count: 20)
        XCTAssertTrue(script.contains("+15551234567"))
    }

    func test_readConversationScript_containsCount() {
        let script = bridge.readConversationScript(contactId: "alice@example.com", count: 25)
        XCTAssertTrue(script.contains("25"))
    }

    func test_readConversationScript_containsChatDb() {
        let script = bridge.readConversationScript(contactId: "+15551234567", count: 20)
        XCTAssertTrue(script.contains("chat.db"))
    }

    func test_readConversationScript_containsIsFromMe() {
        let script = bridge.readConversationScript(contactId: "+15551234567", count: 20)
        XCTAssertTrue(script.contains("is_from_me"))
    }

    func test_readConversationScript_containsDelimiter() {
        let script = bridge.readConversationScript(contactId: "+15551234567", count: 20)
        XCTAssertTrue(script.contains("|||"))
    }

    // MARK: - sendMessage Script Generation

    func test_sendMessageScript_containsMessagesApp() {
        let script = bridge.sendMessageScript(to: "+15551234567", body: "Hello")
        XCTAssertTrue(script.contains("tell application \"Messages\""))
    }

    func test_sendMessageScript_containsRecipient() {
        let script = bridge.sendMessageScript(to: "+15551234567", body: "Hello")
        XCTAssertTrue(script.contains("+15551234567"))
    }

    func test_sendMessageScript_containsBody() {
        let script = bridge.sendMessageScript(to: "+15551234567", body: "Hello World")
        XCTAssertTrue(script.contains("Hello World"))
    }

    func test_sendMessageScript_containsSendCommand() {
        let script = bridge.sendMessageScript(to: "+15551234567", body: "Hello")
        XCTAssertTrue(script.contains("send"))
    }

    func test_sendMessageScript_containsIMessageService() {
        let script = bridge.sendMessageScript(to: "+15551234567", body: "Hello")
        XCTAssertTrue(script.contains("iMessage"))
    }

    // MARK: - searchMessages Script Generation

    func test_searchMessagesScript_containsSqlite() {
        let script = bridge.searchMessagesScript(query: "meeting")
        XCTAssertTrue(script.contains("sqlite3"))
    }

    func test_searchMessagesScript_containsQuery() {
        let script = bridge.searchMessagesScript(query: "meeting tomorrow")
        XCTAssertTrue(script.contains("meeting tomorrow"))
    }

    func test_searchMessagesScript_containsLikeClause() {
        let script = bridge.searchMessagesScript(query: "meeting")
        XCTAssertTrue(script.contains("LIKE"))
    }

    func test_searchMessagesScript_containsDelimiter() {
        let script = bridge.searchMessagesScript(query: "meeting")
        XCTAssertTrue(script.contains("|||"))
    }

    func test_searchMessagesScript_containsChatDb() {
        let script = bridge.searchMessagesScript(query: "test")
        XCTAssertTrue(script.contains("chat.db"))
    }

    // MARK: - listConversations Bridge Integration (no real AppleScript)

    func test_listConversations_executesScript() async throws {
        executor.resultToReturn = "Alice|||Hi there|||2026-03-01\n"

        _ = try await bridge.listConversations(count: 10)

        XCTAssertNotNil(executor.lastScript)
        XCTAssertTrue(executor.lastScript?.contains("chat.db") ?? false)
    }

    func test_listConversations_parsesConversationEntries() async throws {
        executor.resultToReturn = "Alice|||Hi there|||2026-03-01\nBob|||Hey|||2026-03-02\n"

        let result = try await bridge.listConversations(count: 10)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["contactName"] as? String, "Alice")
        XCTAssertEqual(result[0]["lastMessage"] as? String, "Hi there")
        XCTAssertEqual(result[0]["date"] as? String, "2026-03-01")
        XCTAssertEqual(result[1]["contactName"] as? String, "Bob")
    }

    func test_listConversations_withEmptyResult_returnsEmptyArray() async throws {
        executor.resultToReturn = ""

        let result = try await bridge.listConversations(count: 10)

        XCTAssertTrue(result.isEmpty)
    }

    func test_listConversations_whenExecutorThrows_propagatesError() async throws {
        executor.errorToThrow = AppleScriptError.executionFailed("Permission denied")

        do {
            _ = try await bridge.listConversations(count: 10)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Permission denied"))
        }
    }

    // MARK: - readConversation Bridge Integration

    func test_readConversation_executesScript() async throws {
        executor.resultToReturn = "Alice|||Hello!|||2026-03-01\n"

        _ = try await bridge.readConversation(contactId: "+15551234567", count: 50)

        XCTAssertNotNil(executor.lastScript)
        XCTAssertTrue(executor.lastScript?.contains("+15551234567") ?? false)
    }

    func test_readConversation_parsesMessageEntries() async throws {
        executor.resultToReturn = "+15551234567|||Hello!|||2026-03-01\nMe|||Hi back|||2026-03-01\n"

        let result = try await bridge.readConversation(contactId: "+15551234567", count: 50)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["sender"] as? String, "+15551234567")
        XCTAssertEqual(result[0]["body"] as? String, "Hello!")
        XCTAssertEqual(result[1]["sender"] as? String, "Me")
    }

    func test_readConversation_withEmptyResult_returnsEmptyArray() async throws {
        executor.resultToReturn = ""

        let result = try await bridge.readConversation(contactId: "+15551234567", count: 50)

        XCTAssertTrue(result.isEmpty)
    }

    func test_readConversation_whenExecutorThrows_propagatesError() async throws {
        executor.errorToThrow = AppleScriptError.executionFailed("Access denied")

        do {
            _ = try await bridge.readConversation(contactId: "+15551234567", count: 50)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Access denied"))
        }
    }

    // MARK: - sendMessage Bridge Integration

    func test_sendMessage_withConfirmation_executesScript() async throws {
        executor.resultToReturn = ""

        let result = try await bridge.sendMessage(to: "+15551234567", body: "Hello", confirmation: true)

        XCTAssertNotNil(executor.lastScript)
        XCTAssertEqual(result["status"] as? String, "sent")
        XCTAssertEqual(result["to"] as? String, "+15551234567")
    }

    func test_sendMessage_withoutConfirmation_throwsError() async throws {
        do {
            _ = try await bridge.sendMessage(to: "+15551234567", body: "Hello", confirmation: false)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("confirmation"))
        }
    }

    func test_sendMessage_withoutConfirmation_doesNotExecuteScript() async throws {
        do {
            _ = try await bridge.sendMessage(to: "+15551234567", body: "Hello", confirmation: false)
        } catch {
            // Expected
        }
        XCTAssertNil(executor.lastScript)
    }

    func test_sendMessage_whenExecutorThrows_propagatesError() async throws {
        executor.errorToThrow = AppleScriptError.executionFailed("Send failed")

        do {
            _ = try await bridge.sendMessage(to: "+15551234567", body: "Hi", confirmation: true)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Send failed"))
        }
    }

    func test_sendMessage_escapesSpecialCharactersInBody() async throws {
        executor.resultToReturn = ""

        _ = try await bridge.sendMessage(to: "+15551234567", body: "Say \"hello\"", confirmation: true)

        let script = executor.lastScript ?? ""
        // Quotes should be escaped in the script
        XCTAssertFalse(script.contains("Say \"hello\""))
    }

    // MARK: - searchMessages Bridge Integration

    func test_searchMessages_executesScript() async throws {
        executor.resultToReturn = "Alice|||meeting tomorrow|||2026-03-01\n"

        _ = try await bridge.searchMessages(query: "meeting")

        XCTAssertNotNil(executor.lastScript)
        XCTAssertTrue(executor.lastScript?.contains("meeting") ?? false)
    }

    func test_searchMessages_parsesMatchEntries() async throws {
        executor.resultToReturn = "Alice|||lunch meeting|||2026-03-01\nBob|||team meeting|||2026-03-02\n"

        let result = try await bridge.searchMessages(query: "meeting")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["body"] as? String, "lunch meeting")
        XCTAssertEqual(result[1]["body"] as? String, "team meeting")
    }

    func test_searchMessages_withEmptyResult_returnsEmptyArray() async throws {
        executor.resultToReturn = ""

        let result = try await bridge.searchMessages(query: "nothing")

        XCTAssertTrue(result.isEmpty)
    }

    func test_searchMessages_whenExecutorThrows_propagatesError() async throws {
        executor.errorToThrow = AppleScriptError.executionFailed("Search error")

        do {
            _ = try await bridge.searchMessages(query: "test")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Search error"))
        }
    }

    // MARK: - AppleScriptError

    func test_appleScriptError_executionFailed_hasDescriptiveMessage() {
        let error = AppleScriptError.executionFailed("something went wrong")
        XCTAssertTrue(error.errorDescription?.contains("something went wrong") ?? false)
    }

    func test_appleScriptError_compilationFailed_hasDescriptiveMessage() {
        let error = AppleScriptError.compilationFailed("syntax error")
        XCTAssertTrue(error.errorDescription?.contains("syntax error") ?? false)
    }

    func test_appleScriptError_noResult_hasDescription() {
        let error = AppleScriptError.noResult
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - MessagesError

    func test_messagesError_confirmationRequired_hasDescriptiveMessage() {
        let error = MessagesError.confirmationRequired
        XCTAssertTrue(error.errorDescription?.contains("confirmation") ?? false)
    }
}
