import XCTest
@testable import MacOSLocalMCP

final class MailToolTests: XCTestCase {

    // MARK: - Helpers

    private func makeProvider() -> MockMailProvider {
        MockMailProvider()
    }

    private func makeHandlers(provider: MockMailProvider) -> [String: MCPToolHandler] {
        let tool = MailTool(provider: provider)
        let handlers = tool.createHandlers()
        var map: [String: MCPToolHandler] = [:]
        for h in handlers {
            map[h.toolName] = h
        }
        return map
    }

    // MARK: - list_mailboxes

    func testListMailboxes_happyPath() async throws {
        let provider = makeProvider()
        provider.listMailboxesResult = [
            ["name": "INBOX", "account": "me@example.com"],
            ["name": "Sent", "account": "me@example.com"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_mailboxes"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listMailboxesCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("INBOX"))
        XCTAssertTrue(text.contains("Sent"))
    }

    func testListMailboxes_providerThrows() async throws {
        let provider = makeProvider()
        provider.listMailboxesError = TestError.generic("mailboxes failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_mailboxes"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("mailboxes failed"))
    }

    func testListMailboxes_returnsEmptyArray_whenNoMailboxes() async throws {
        let provider = makeProvider()
        provider.listMailboxesResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_mailboxes"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertEqual(text, "[]")
    }

    // MARK: - list_recent_mail

    func testListRecentMail_happyPath_defaults() async throws {
        let provider = makeProvider()
        provider.listRecentMailResult = [
            ["id": "msg1", "subject": "Hello", "from": "sender@example.com"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_recent_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listRecentMailCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Hello"))
    }

    func testListRecentMail_withAllParameters() async throws {
        let provider = makeProvider()
        provider.listRecentMailResult = [["id": "msg2", "subject": "Re: Test"]]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_recent_mail"])
        let args: [String: JSONValue] = [
            "count": .int(10),
            "mailbox": .string("INBOX"),
            "unread_only": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        XCTAssertTrue(provider.listRecentMailCalled)
    }

    func testListRecentMail_providerThrows() async throws {
        let provider = makeProvider()
        provider.listRecentMailError = TestError.generic("mail fetch failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_recent_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("mail fetch failed"))
    }

    // MARK: - search_mail

    func testSearchMail_happyPath() async throws {
        let provider = makeProvider()
        provider.searchMailResult = [
            ["id": "msg3", "subject": "Invoice", "from": "billing@corp.com"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_mail"])
        let args: [String: JSONValue] = [
            "sender": .string("billing@corp.com"),
            "subject": .string("Invoice")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.searchMailCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Invoice"))
    }

    func testSearchMail_noParameters_stillCalls() async throws {
        let provider = makeProvider()
        provider.searchMailResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.searchMailCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testSearchMail_withDateRange() async throws {
        let provider = makeProvider()
        provider.searchMailResult = [["id": "msg4", "subject": "Report"]]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_mail"])
        let args: [String: JSONValue] = [
            "date_from": .string("2024-01-01T00:00:00Z"),
            "date_to": .string("2024-12-31T23:59:59Z"),
            "has_attachment": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        XCTAssertTrue(provider.searchMailCalled)
    }

    func testSearchMail_providerThrows() async throws {
        let provider = makeProvider()
        provider.searchMailError = TestError.generic("search error")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["search_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("search error"))
    }

    // MARK: - read_mail

    func testReadMail_happyPath() async throws {
        let provider = makeProvider()
        provider.readMailResult = [
            "id": "msg5",
            "subject": "Project Update",
            "body": "Here is the update..."
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["read_mail"])
        let args: [String: JSONValue] = ["id": .string("msg5")]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.readMailCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Project Update"))
    }

    func testReadMail_missingId() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["read_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(provider.readMailCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("missing") || text.lowercased().contains("required"))
    }

    func testReadMail_emptyArgumentsMissingId() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["read_mail"])
        let args: [String: JSONValue] = [:]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.readMailCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testReadMail_providerThrows() async throws {
        let provider = makeProvider()
        provider.readMailError = TestError.generic("message not found")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["read_mail"])
        let args: [String: JSONValue] = ["id": .string("missing-id")]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("message not found"))
    }

    // MARK: - create_draft

    func testCreateDraft_happyPath() async throws {
        let provider = makeProvider()
        provider.createDraftResult = ["id": "draft1", "subject": "Hello World"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "to": .array([.string("alice@example.com"), .string("bob@example.com")]),
            "subject": .string("Hello World"),
            "body": .string("Body text here")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.createDraftCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("draft1"))
    }

    func testCreateDraft_withOptionalCcBcc() async throws {
        let provider = makeProvider()
        provider.createDraftResult = ["id": "draft2"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "to": .array([.string("alice@example.com")]),
            "cc": .array([.string("cc@example.com")]),
            "bcc": .array([.string("bcc@example.com")]),
            "subject": .string("Test Subject"),
            "body": .string("Test body"),
            "is_html": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        XCTAssertTrue(provider.createDraftCalled)
    }

    func testCreateDraft_missingTo() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "subject": .string("Hello"),
            "body": .string("Body")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.createDraftCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("missing") || text.lowercased().contains("required"))
    }

    func testCreateDraft_missingSubject() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "to": .array([.string("alice@example.com")]),
            "body": .string("Body")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.createDraftCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testCreateDraft_missingBody() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "to": .array([.string("alice@example.com")]),
            "subject": .string("Hello")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.createDraftCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testCreateDraft_providerThrows() async throws {
        let provider = makeProvider()
        provider.createDraftError = TestError.generic("draft creation failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["create_draft"])
        let args: [String: JSONValue] = [
            "to": .array([.string("alice@example.com")]),
            "subject": .string("Hello"),
            "body": .string("Body")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("draft creation failed"))
    }

    // MARK: - send_draft

    func testSendDraft_happyPath() async throws {
        let provider = makeProvider()
        provider.sendDraftResult = ["id": "draft1", "sent": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["send_draft"])
        let args: [String: JSONValue] = [
            "id": .string("draft1"),
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.sendDraftCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("draft1"))
    }

    func testSendDraft_missingId() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["send_draft"])
        let args: [String: JSONValue] = [
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.sendDraftCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("missing") || text.lowercased().contains("required"))
    }

    func testSendDraft_noConfirmation_defaultsFalse() async throws {
        let provider = makeProvider()
        provider.sendDraftResult = ["id": "draft1", "sent": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["send_draft"])
        let args: [String: JSONValue] = [
            "id": .string("draft1")
        ]

        // Without confirmation, confirmation defaults to false but we still call provider
        let result = try await handler.handle(arguments: args)

        // The tool should still work — confirmation is passed to the provider
        XCTAssertTrue(provider.sendDraftCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testSendDraft_providerThrows() async throws {
        let provider = makeProvider()
        provider.sendDraftError = TestError.generic("send failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["send_draft"])
        let args: [String: JSONValue] = [
            "id": .string("draft1"),
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("send failed"))
    }

    // MARK: - move_message

    func testMoveMessage_happyPath() async throws {
        let provider = makeProvider()
        provider.moveMessageResult = ["id": "msg6", "mailbox": "Archive"]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg6"),
            "to_mailbox": .string("Archive")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.moveMessageCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Archive"))
    }

    func testMoveMessage_missingId() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_message"])
        let args: [String: JSONValue] = [
            "to_mailbox": .string("Archive")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.moveMessageCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("missing") || text.lowercased().contains("required"))
    }

    func testMoveMessage_missingToMailbox() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg6")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.moveMessageCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testMoveMessage_providerThrows() async throws {
        let provider = makeProvider()
        provider.moveMessageError = TestError.generic("move failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["move_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg6"),
            "to_mailbox": .string("Archive")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("move failed"))
    }

    // MARK: - flag_message

    func testFlagMessage_happyPath_setFlagged() async throws {
        let provider = makeProvider()
        provider.flagMessageResult = ["id": "msg7", "flagged": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["flag_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg7"),
            "flagged": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.flagMessageCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("msg7"))
    }

    func testFlagMessage_setRead() async throws {
        let provider = makeProvider()
        provider.flagMessageResult = ["id": "msg8", "read": true]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["flag_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg8"),
            "read": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.flagMessageCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testFlagMessage_setBothFlaggedAndRead() async throws {
        let provider = makeProvider()
        provider.flagMessageResult = ["id": "msg9", "flagged": true, "read": false]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["flag_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg9"),
            "flagged": .bool(true),
            "read": .bool(false)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
    }

    func testFlagMessage_missingId() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["flag_message"])
        let args: [String: JSONValue] = [
            "flagged": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.flagMessageCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("missing") || text.lowercased().contains("required"))
    }

    func testFlagMessage_providerThrows() async throws {
        let provider = makeProvider()
        provider.flagMessageError = TestError.generic("flag failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["flag_message"])
        let args: [String: JSONValue] = [
            "id": .string("msg7"),
            "flagged": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("flag failed"))
    }

    // MARK: - ClosureToolHandler

    func testClosureToolHandler_toolName() {
        let handler = ClosureToolHandler(toolName: "test_tool") { _ in .text("ok") }
        XCTAssertEqual(handler.toolName, "test_tool")
    }

    func testClosureToolHandler_invokesClosureWithArguments() async throws {
        var capturedArgs: [String: JSONValue]?
        let handler = ClosureToolHandler(toolName: "test_tool") { args in
            capturedArgs = args
            return .text("result")
        }
        let args: [String: JSONValue] = ["key": .string("value")]

        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.content.first?.text, "result")
        XCTAssertEqual(capturedArgs?["key"], .string("value"))
    }

    func testClosureToolHandler_propagatesThrows() async throws {
        let handler = ClosureToolHandler(toolName: "failing_tool") { _ in
            throw TestError.generic("closure failed")
        }

        await XCTAssertThrowsErrorAsync(try await handler.handle(arguments: nil)) { error in
            XCTAssertEqual((error as? TestError)?.message, "closure failed")
        }
    }

    // MARK: - find_unanswered_mail

    func testFindUnansweredMail_happyPath_noParams() async throws {
        let provider = makeProvider()
        provider.findUnansweredMailResult = [
            ["id": "m1", "subject": "Hello", "from": "alice@example.com"],
            ["id": "m2", "subject": "Meeting", "from": "bob@example.com"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_unanswered_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.findUnansweredMailCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertTrue(text.contains("Meeting"))
    }

    func testFindUnansweredMail_withDaysAndMailbox() async throws {
        let provider = makeProvider()
        provider.findUnansweredMailResult = [["id": "m3", "subject": "Report"]]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_unanswered_mail"])
        let args: [String: JSONValue] = [
            "days": .int(14),
            "mailbox": .string("INBOX")
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.findUnansweredMailCalled)
        XCTAssertFalse(result.isError ?? false)
        XCTAssertEqual(provider.lastFindUnansweredMailDays, 14)
        XCTAssertEqual(provider.lastFindUnansweredMailMailbox, "INBOX")
    }

    func testFindUnansweredMail_providerThrows() async throws {
        let provider = makeProvider()
        provider.findUnansweredMailError = TestError.generic("unanswered search failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_unanswered_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("unanswered search failed"))
    }

    func testFindUnansweredMail_emptyResult() async throws {
        let provider = makeProvider()
        provider.findUnansweredMailResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_unanswered_mail"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertEqual(text, "[]")
    }

    // MARK: - find_threads_awaiting_reply

    func testFindThreadsAwaitingReply_happyPath() async throws {
        let provider = makeProvider()
        provider.findThreadsAwaitingReplyResult = [
            ["id": "t1", "subject": "Project Update", "lastSender": "carol@example.com"]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_threads_awaiting_reply"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.findThreadsAwaitingReplyCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Project Update"))
    }

    func testFindThreadsAwaitingReply_withDaysParam() async throws {
        let provider = makeProvider()
        provider.findThreadsAwaitingReplyResult = []
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_threads_awaiting_reply"])
        let args: [String: JSONValue] = ["days": .int(30)]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.findThreadsAwaitingReplyCalled)
        XCTAssertFalse(result.isError ?? false)
        XCTAssertEqual(provider.lastFindThreadsAwaitingReplyDays, 30)
    }

    func testFindThreadsAwaitingReply_providerThrows() async throws {
        let provider = makeProvider()
        provider.findThreadsAwaitingReplyError = TestError.generic("threads error")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["find_threads_awaiting_reply"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("threads error"))
    }

    // MARK: - list_senders_by_frequency

    func testListSendersByFrequency_happyPath() async throws {
        let provider = makeProvider()
        provider.listSendersByFrequencyResult = [
            ["sender": "newsletter@example.com", "count": 42],
            ["sender": "boss@example.com", "count": 15]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_senders_by_frequency"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listSendersByFrequencyCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("newsletter@example.com"))
        XCTAssertTrue(text.contains("boss@example.com"))
    }

    func testListSendersByFrequency_withDaysAndLimit() async throws {
        let provider = makeProvider()
        provider.listSendersByFrequencyResult = [["sender": "a@b.com", "count": 5]]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_senders_by_frequency"])
        let args: [String: JSONValue] = [
            "days": .int(7),
            "limit": .int(10)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.listSendersByFrequencyCalled)
        XCTAssertFalse(result.isError ?? false)
        XCTAssertEqual(provider.lastListSendersByFrequencyDays, 7)
        XCTAssertEqual(provider.lastListSendersByFrequencyLimit, 10)
    }

    func testListSendersByFrequency_providerThrows() async throws {
        let provider = makeProvider()
        provider.listSendersByFrequencyError = TestError.generic("frequency error")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["list_senders_by_frequency"])

        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("frequency error"))
    }

    // MARK: - bulk_archive_messages

    func testBulkArchiveMessages_happyPath() async throws {
        let provider = makeProvider()
        provider.bulkArchiveMessagesResult = [
            ["id": "m1", "archived": true],
            ["id": "m2", "archived": true]
        ]
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "ids": .array([.string("m1"), .string("m2")]),
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.bulkArchiveMessagesCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("m1"))
        XCTAssertTrue(text.contains("m2"))
    }

    func testBulkArchiveMessages_missingIds() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.bulkArchiveMessagesCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("ids"))
    }

    func testBulkArchiveMessages_confirmationFalse_returnsError() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "ids": .array([.string("m1")]),
            "confirmation": .bool(false)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.bulkArchiveMessagesCalled)
        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.lowercased().contains("confirmation"))
    }

    func testBulkArchiveMessages_confirmationMissing_returnsError() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "ids": .array([.string("m1")])
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.bulkArchiveMessagesCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testBulkArchiveMessages_emptyIds_returnsError() async throws {
        let provider = makeProvider()
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "ids": .array([]),
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(provider.bulkArchiveMessagesCalled)
        XCTAssertTrue(result.isError ?? false)
    }

    func testBulkArchiveMessages_providerThrows() async throws {
        let provider = makeProvider()
        provider.bulkArchiveMessagesError = TestError.generic("archive failed")
        let handlers = makeHandlers(provider: provider)
        let handler = try XCTUnwrap(handlers["bulk_archive_messages"])
        let args: [String: JSONValue] = [
            "ids": .array([.string("m1")]),
            "confirmation": .bool(true)
        ]

        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("archive failed"))
    }

    // MARK: - MailTool handler count

    func testMailTool_createHandlers_returnsTwelveHandlers() {
        let provider = makeProvider()
        let tool = MailTool(provider: provider)
        let handlers = tool.createHandlers()
        XCTAssertEqual(handlers.count, 12)
    }

    func testMailTool_createHandlers_hasCorrectToolNames() {
        let provider = makeProvider()
        let tool = MailTool(provider: provider)
        let handlers = tool.createHandlers()
        let names = Set(handlers.map { $0.toolName })
        let expected: Set<String> = [
            "list_mailboxes",
            "list_recent_mail",
            "search_mail",
            "read_mail",
            "create_draft",
            "send_draft",
            "move_message",
            "flag_message",
            "find_unanswered_mail",
            "find_threads_awaiting_reply",
            "list_senders_by_frequency",
            "bulk_archive_messages"
        ]
        XCTAssertEqual(names, expected)
    }
}

// MARK: - Test Helpers

enum TestError: Error, Equatable {
    case generic(String)

    var message: String {
        switch self {
        case .generic(let msg): return msg
        }
    }
}

extension TestError: LocalizedError {
    var errorDescription: String? { message }
}

/// Helper to assert that an async expression throws an error.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown" + (message.isEmpty ? "" : ": \(message)"), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
