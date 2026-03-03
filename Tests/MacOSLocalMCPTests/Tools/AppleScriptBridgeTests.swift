import XCTest
@testable import MacOSLocalMCP

// MARK: - AppleScriptBridgeTests

final class AppleScriptBridgeTests: XCTestCase {

    // MARK: - ScriptExecuting protocol conformance

    func testMockScriptExecutor_recordsScript() throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "hello"
        let result = try executor.executeScript("some AppleScript")
        XCTAssertEqual(result, "hello")
        XCTAssertEqual(executor.lastScript, "some AppleScript")
    }

    func testMockScriptExecutor_throwsWhenConfigured() {
        let executor = MockScriptExecutor()
        executor.errorToThrow = AppleScriptError.executionFailed("test error")
        XCTAssertThrowsError(try executor.executeScript("script")) { error in
            guard case AppleScriptError.executionFailed(let msg) = error else {
                XCTFail("Expected AppleScriptError.executionFailed"); return
            }
            XCTAssertEqual(msg, "test error")
        }
    }

    // MARK: - AppleScriptError

    func testAppleScriptError_localizedDescription() {
        let error = AppleScriptError.executionFailed("oops")
        XCTAssertTrue(error.localizedDescription.contains("oops"))
        XCTAssertTrue(error.localizedDescription.contains("AppleScript"))
    }

    func testAppleScriptError_equality() {
        XCTAssertEqual(
            AppleScriptError.executionFailed("a"),
            AppleScriptError.executionFailed("a")
        )
        XCTAssertNotEqual(
            AppleScriptError.executionFailed("a"),
            AppleScriptError.executionFailed("b")
        )
    }
}

// MARK: - MailBridgeTests

final class MailBridgeTests: XCTestCase {

    // MARK: - Helpers

    private func makeBridge(executor: MockScriptExecutor) -> MailBridge {
        MailBridge(scriptRunner: executor)
    }

    // MARK: - listMailboxes

    func testListMailboxes_generatesScriptContainingMailApp() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.listMailboxes()

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Mail"), "Script should reference Mail application")
        XCTAssertTrue(script.contains("accounts"), "Script should iterate accounts")
        XCTAssertTrue(script.contains("mailboxes"), "Script should iterate mailboxes")
    }

    func testListMailboxes_parsesTabDelimitedOutput() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "me@example.com\tINBOX\nme@example.com\tSent\n"
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.listMailboxes()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0]["account"] as? String, "me@example.com")
        XCTAssertEqual(result[0]["name"] as? String, "INBOX")
        XCTAssertEqual(result[1]["name"] as? String, "Sent")
    }

    func testListMailboxes_emptyOutput_returnsEmptyArray() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.listMailboxes()

        XCTAssertTrue(result.isEmpty)
    }

    func testListMailboxes_propagatesError() async throws {
        let executor = MockScriptExecutor()
        executor.errorToThrow = AppleScriptError.executionFailed("Mail not running")
        let bridge = makeBridge(executor: executor)

        do {
            _ = try await bridge.listMailboxes()
            XCTFail("Expected error")
        } catch let error as AppleScriptError {
            if case .executionFailed(let msg) = error {
                XCTAssertTrue(msg.contains("Mail not running"))
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    // MARK: - listRecentMail

    func testListRecentMail_scriptContainsCount() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.listRecentMail(count: 42, mailbox: nil, unreadOnly: false)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("42"), "Script should include the requested count")
    }

    func testListRecentMail_unreadOnly_includesReadStatusFilter() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.listRecentMail(count: 10, mailbox: nil, unreadOnly: true)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("read status"), "Script should filter by read status")
    }

    func testListRecentMail_withMailbox_includesMailboxName() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.listRecentMail(count: 10, mailbox: "Archive", unreadOnly: false)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Archive"), "Script should reference the specified mailbox")
    }

    func testListRecentMail_parsesTabDelimitedOutput() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "id1\tHello World\tsender@example.com\t2024-01-01\ttrue\n"
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.listRecentMail(count: 10, mailbox: nil, unreadOnly: false)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["id"] as? String, "id1")
        XCTAssertEqual(result[0]["subject"] as? String, "Hello World")
        XCTAssertEqual(result[0]["from"] as? String, "sender@example.com")
    }

    // MARK: - searchMail

    func testSearchMail_withSender_includesSenderInScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.searchMail(
            sender: "alice@example.com",
            subject: nil, body: nil, dateFrom: nil, dateTo: nil, mailbox: nil, hasAttachment: nil
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("alice@example.com"), "Script should include sender filter")
        XCTAssertTrue(script.contains("sender contains"), "Script should use sender contains clause")
    }

    func testSearchMail_withSubject_includesSubjectInScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.searchMail(
            sender: nil,
            subject: "Invoice",
            body: nil, dateFrom: nil, dateTo: nil, mailbox: nil, hasAttachment: nil
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Invoice"), "Script should include subject filter")
        XCTAssertTrue(script.contains("subject contains"), "Script should use subject contains clause")
    }

    func testSearchMail_withHasAttachment_includesAttachmentClause() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.searchMail(
            sender: nil, subject: nil, body: nil, dateFrom: nil, dateTo: nil,
            mailbox: nil, hasAttachment: true
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("mail attachments") || script.contains("attachment"), "Script should include attachment filter")
    }

    func testSearchMail_withMailbox_includesMailboxInScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.searchMail(
            sender: nil, subject: nil, body: nil, dateFrom: nil, dateTo: nil,
            mailbox: "Work", hasAttachment: nil
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Work"), "Script should reference the specified mailbox")
    }

    func testSearchMail_noFilters_scriptStillValid() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.searchMail(
            sender: nil, subject: nil, body: nil, dateFrom: nil, dateTo: nil,
            mailbox: nil, hasAttachment: nil
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Mail"), "Script should reference Mail app")
    }

    // MARK: - readMail

    func testReadMail_scriptContainsMessageId() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "Subject\tsender@ex.com\tto@ex.com\t2024-01-01\tBody text\tfalse"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.readMail(id: "unique-message-id-123")

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("unique-message-id-123"), "Script should include the message ID")
        XCTAssertTrue(script.contains("message id"), "Script should filter by message id")
    }

    func testReadMail_parsesOutput() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "Hello Subject\tsender@ex.com\tto@ex.com\t2024-01-01\tHello body\ttrue"
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.readMail(id: "msg-id-1")

        XCTAssertEqual(result["id"] as? String, "msg-id-1")
        XCTAssertEqual(result["subject"] as? String, "Hello Subject")
        XCTAssertEqual(result["from"] as? String, "sender@ex.com")
        XCTAssertEqual(result["body"] as? String, "Hello body")
    }

    // MARK: - createDraft

    func testCreateDraft_scriptContainsSubjectAndBody() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "new-draft-id"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.createDraft(
            to: ["alice@example.com"],
            cc: nil, bcc: nil,
            subject: "Test Subject",
            body: "Test Body",
            isHTML: false
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Test Subject"), "Script should include subject")
        XCTAssertTrue(script.contains("Test Body"), "Script should include body")
        XCTAssertTrue(script.contains("alice@example.com"), "Script should include recipient")
        XCTAssertTrue(script.contains("outgoing message"), "Script should create outgoing message")
    }

    func testCreateDraft_withCC_includesCCInScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "draft-id"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.createDraft(
            to: ["alice@example.com"],
            cc: ["cc@example.com"],
            bcc: nil,
            subject: "Subject",
            body: "Body",
            isHTML: false
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("cc@example.com"), "Script should include CC address")
        XCTAssertTrue(script.contains("cc recipients"), "Script should reference cc recipients")
    }

    func testCreateDraft_withBCC_includesBCCInScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "draft-id"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.createDraft(
            to: ["alice@example.com"],
            cc: nil,
            bcc: ["bcc@example.com"],
            subject: "Subject",
            body: "Body",
            isHTML: false
        )

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("bcc@example.com"), "Script should include BCC address")
        XCTAssertTrue(script.contains("bcc recipients"), "Script should reference bcc recipients")
    }

    func testCreateDraft_returnsIdFromScript() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "returned-draft-id"
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.createDraft(
            to: ["alice@example.com"],
            cc: nil, bcc: nil,
            subject: "Hello",
            body: "World",
            isHTML: false
        )

        XCTAssertEqual(result["id"] as? String, "returned-draft-id")
        XCTAssertEqual(result["subject"] as? String, "Hello")
    }

    // MARK: - sendDraft

    func testSendDraft_scriptContainsMessageId() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "draft-id-to-send"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.sendDraft(id: "draft-id-to-send", confirmation: true)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("draft-id-to-send"), "Script should include draft ID")
        XCTAssertTrue(script.contains("send"), "Script should send the message")
    }

    func testSendDraft_resultContainsSentFlag() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "draft-123"
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.sendDraft(id: "draft-123", confirmation: true)

        XCTAssertEqual(result["sent"] as? Bool, true)
    }

    // MARK: - moveMessage

    func testMoveMessage_scriptContainsMessageIdAndDestination() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "msg-id-99"
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.moveMessage(id: "msg-id-99", toMailbox: "Archive")

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("msg-id-99"), "Script should include message ID")
        XCTAssertTrue(script.contains("Archive"), "Script should include destination mailbox")
        XCTAssertTrue(script.contains("move"), "Script should move the message")
    }

    func testMoveMessage_resultContainsIdAndMailbox() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.moveMessage(id: "msg-abc", toMailbox: "Work")

        XCTAssertEqual(result["id"] as? String, "msg-abc")
        XCTAssertEqual(result["mailbox"] as? String, "Work")
    }

    // MARK: - flagMessage

    func testFlagMessage_withFlagged_scriptSetsFlaggedStatus() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.flagMessage(id: "msg-flag-1", flagged: true, read: nil)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("msg-flag-1"), "Script should include message ID")
        XCTAssertTrue(script.contains("flagged status"), "Script should set flagged status")
        XCTAssertTrue(script.contains("true"), "Script should set flagged to true")
    }

    func testFlagMessage_withRead_scriptSetsReadStatus() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        _ = try await bridge.flagMessage(id: "msg-read-1", flagged: nil, read: false)

        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("read status"), "Script should set read status")
        XCTAssertTrue(script.contains("false"), "Script should set read to false")
    }

    func testFlagMessage_resultContainsUpdatedValues() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = ""
        let bridge = makeBridge(executor: executor)

        let result = try await bridge.flagMessage(id: "msg-x", flagged: true, read: false)

        XCTAssertEqual(result["id"] as? String, "msg-x")
        XCTAssertEqual(result["flagged"] as? Bool, true)
        XCTAssertEqual(result["read"] as? Bool, false)
    }

    // MARK: - String escaping

    func testMailBridge_escapesDoubleQuotesInMessageId() async throws {
        let executor = MockScriptExecutor()
        executor.resultToReturn = "Sub\tsender\tto\tdate\tbody\tfalse"
        let bridge = makeBridge(executor: executor)

        // An id with a double quote should be escaped in the script
        _ = try await bridge.readMail(id: "id-with-\"quote")

        let script = try XCTUnwrap(executor.lastScript)
        // The quote should be escaped as \"
        XCTAssertFalse(script.contains("id-with-\"quote\""), "Unescaped quote should not appear")
    }
}
