import XCTest
@testable import MacOSLocalMCP

final class CrossAppToolTests: XCTestCase {

    // MARK: - Helpers

    private func makeTool(
        calendar: MockCalendarProvider = MockCalendarProvider(),
        contacts: MockContactsProvider = MockContactsProvider(),
        mail: MockMailProvider = MockMailProvider(),
        messages: MockMessagesProvider = MockMessagesProvider()
    ) -> CrossAppTool {
        CrossAppTool(
            calendarProvider: calendar,
            contactsProvider: contacts,
            mailProvider: mail,
            messagesProvider: messages
        )
    }

    private func makeHandlers(
        calendar: MockCalendarProvider = MockCalendarProvider(),
        contacts: MockContactsProvider = MockContactsProvider(),
        mail: MockMailProvider = MockMailProvider(),
        messages: MockMessagesProvider = MockMessagesProvider()
    ) -> [String: MCPToolHandler] {
        let tool = makeTool(calendar: calendar, contacts: contacts, mail: mail, messages: messages)
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

    // MARK: - createHandlers

    func testCreateHandlersReturnsTwoHandlers() {
        let tool = makeTool()
        let handlers = tool.createHandlers()
        XCTAssertEqual(handlers.count, 2)
    }

    func testCreateHandlersRegistersExpectedNames() {
        let handlers = makeHandlers()
        XCTAssertNotNil(handlers["meeting_context"])
        XCTAssertNotNil(handlers["contact_360"])
    }

    // MARK: - meeting_context

    func test_meetingContext_happyPath() async throws {
        let calendar = MockCalendarProvider()
        calendar.listEventsResult = [
            ["id": "ev-1", "title": "Team Standup", "startDate": "2026-03-01T09:00:00Z", "endDate": "2026-03-01T09:30:00Z"]
        ]
        let contacts = MockContactsProvider()
        contacts.searchContactsResult = [
            ["firstName": "Alice", "lastName": "Smith", "email": "alice@example.com", "phone": "", "company": "Acme"]
        ]
        let handlers = makeHandlers(calendar: calendar, contacts: contacts)
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-01T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(calendar.listEventsCalled)
        let body = text(result)
        XCTAssertTrue(body.contains("Team Standup"))
        XCTAssertTrue(body.contains("eventCount"))
    }

    func test_meetingContext_missingStartDate_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: ["end_date": .string("2026-03-01T23:59:59Z")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("start_date"))
    }

    func test_meetingContext_missingEndDate_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: ["start_date": .string("2026-03-01T00:00:00Z")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("end_date"))
    }

    func test_meetingContext_nilArgs_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
    }

    func test_meetingContext_invalidDate_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: [
            "start_date": .string("not-a-date"),
            "end_date": .string("2026-03-01T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Invalid start_date"))
    }

    func test_meetingContext_calendarError_returnsError() async throws {
        let calendar = MockCalendarProvider()
        calendar.listEventsError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
        let handlers = makeHandlers(calendar: calendar)
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-01T23:59:59Z")
        ])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Calendar access denied"))
    }

    func test_meetingContext_noEvents_returnsEmptyList() async throws {
        let calendar = MockCalendarProvider()
        calendar.listEventsResult = []
        let handlers = makeHandlers(calendar: calendar)
        let handler = try XCTUnwrap(handlers["meeting_context"])

        let result = try await call(handler, args: [
            "start_date": .string("2026-03-01T00:00:00Z"),
            "end_date": .string("2026-03-01T23:59:59Z")
        ])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(text(result).contains("\"eventCount\":0"))
    }

    // MARK: - contact_360

    func test_contact360_happyPath() async throws {
        let contacts = MockContactsProvider()
        contacts.searchContactsResult = [
            ["firstName": "Bob", "lastName": "Jones", "email": "bob@example.com", "phone": "+1234567890", "company": "Corp"]
        ]
        let mail = MockMailProvider()
        mail.searchMailResult = [
            ["id": "mail-1", "subject": "Hello Bob", "sender": "alice@example.com"]
        ]
        let messages = MockMessagesProvider()
        messages.searchMessagesResult = [
            ["id": "msg-1", "body": "Hey Bob"]
        ]
        let calendar = MockCalendarProvider()
        calendar.searchEventsResult = [
            ["id": "ev-1", "title": "Lunch with Bob"]
        ]
        let handlers = makeHandlers(calendar: calendar, contacts: contacts, mail: mail, messages: messages)
        let handler = try XCTUnwrap(handlers["contact_360"])

        let result = try await call(handler, args: ["query": .string("Bob")])

        XCTAssertFalse(isError(result))
        XCTAssertTrue(contacts.searchContactsCalled)
        XCTAssertTrue(mail.searchMailCalled)
        XCTAssertTrue(messages.searchMessagesCalled)
        XCTAssertTrue(calendar.searchEventsCalled)
        let body = text(result)
        XCTAssertTrue(body.contains("Bob"))
        XCTAssertTrue(body.contains("emailCount"))
    }

    func test_contact360_missingQuery_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["contact_360"])

        let result = try await call(handler, args: [:])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("query"))
    }

    func test_contact360_nilArgs_returnsError() async throws {
        let handlers = makeHandlers()
        let handler = try XCTUnwrap(handlers["contact_360"])

        let result = try await call(handler, args: nil)

        XCTAssertTrue(isError(result))
    }

    func test_contact360_noContactFound_returnsError() async throws {
        let contacts = MockContactsProvider()
        contacts.searchContactsResult = []
        let handlers = makeHandlers(contacts: contacts)
        let handler = try XCTUnwrap(handlers["contact_360"])

        let result = try await call(handler, args: ["query": .string("Nobody")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("No contact found"))
    }

    func test_contact360_contactsError_returnsError() async throws {
        let contacts = MockContactsProvider()
        contacts.searchContactsError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Contacts access denied"])
        let handlers = makeHandlers(contacts: contacts)
        let handler = try XCTUnwrap(handlers["contact_360"])

        let result = try await call(handler, args: ["query": .string("Bob")])

        XCTAssertTrue(isError(result))
        XCTAssertTrue(text(result).contains("Contacts access denied"))
    }
}
