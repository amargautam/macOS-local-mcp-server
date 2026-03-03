import XCTest
@testable import MacOSLocalMCP

final class NotesToolTests: XCTestCase {

    var mock: MockNotesProvider!
    var tool: NotesTool!
    var handlers: [String: MCPToolHandler]!

    override func setUp() {
        super.setUp()
        mock = MockNotesProvider()
        tool = NotesTool(provider: mock)
        handlers = Dictionary(uniqueKeysWithValues: tool.createHandlers().map { ($0.toolName, $0) })
    }

    // MARK: - Handler Registration

    func testCreateHandlersReturns9Handlers() {
        XCTAssertEqual(tool.createHandlers().count, 9)
    }

    func testAllExpectedHandlersAreRegistered() {
        let expectedNames = [
            "list_note_folders",
            "list_notes",
            "read_note",
            "create_note",
            "update_note",
            "search_notes",
            "delete_note",
            "append_to_note",
            "find_stale_notes"
        ]
        for name in expectedNames {
            XCTAssertNotNil(handlers[name], "Missing handler for \(name)")
        }
    }

    func testHandlerToolNamesMatchKeys() {
        for (key, handler) in handlers {
            XCTAssertEqual(handler.toolName, key)
        }
    }

    // MARK: - list_note_folders

    func testListNoteFoldersCallsProvider() async throws {
        mock.listNoteFoldersResult = [
            ["id": "1", "name": "Notes"],
            ["id": "2", "name": "Work"]
        ]
        let handler = try XCTUnwrap(handlers["list_note_folders"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(mock.listNoteFoldersCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testListNoteFoldersReturnsJSONText() async throws {
        mock.listNoteFoldersResult = [
            ["id": "folder-1", "name": "Personal"],
            ["id": "folder-2", "name": "Work"]
        ]
        let handler = try XCTUnwrap(handlers["list_note_folders"])
        let result = try await handler.handle(arguments: nil)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Personal") || text.contains("folder"))
    }

    func testListNoteFoldersEmptyReturnsEmptyJSON() async throws {
        mock.listNoteFoldersResult = []
        let handler = try XCTUnwrap(handlers["list_note_folders"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func testListNoteFoldersErrorReturnsErrorResult() async throws {
        mock.listNoteFoldersError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notes not accessible"])
        let handler = try XCTUnwrap(handlers["list_note_folders"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Notes not accessible") ?? false)
    }

    // MARK: - list_notes

    func testListNotesCallsProvider() async throws {
        mock.listNotesResult = [["id": "n1", "title": "My Note"]]
        let handler = try XCTUnwrap(handlers["list_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(mock.listNotesCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testListNotesPassesFolderNameArgument() async throws {
        mock.listNotesResult = []
        let handler = try XCTUnwrap(handlers["list_notes"])
        _ = try await handler.handle(arguments: ["folder_name": .string("Work")])
        XCTAssertTrue(mock.listNotesCalled)
    }

    func testListNotesPassesSortByArgument() async throws {
        mock.listNotesResult = []
        let handler = try XCTUnwrap(handlers["list_notes"])
        _ = try await handler.handle(arguments: ["sort_by": .string("modified")])
        XCTAssertTrue(mock.listNotesCalled)
    }

    func testListNotesReturnsJSONText() async throws {
        mock.listNotesResult = [
            ["id": "n1", "title": "Shopping List", "folder": "Personal"]
        ]
        let handler = try XCTUnwrap(handlers["list_notes"])
        let result = try await handler.handle(arguments: nil)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Shopping List") || text.contains("n1"))
    }

    func testListNotesErrorReturnsErrorResult() async throws {
        mock.listNotesError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
        let handler = try XCTUnwrap(handlers["list_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
    }

    func testListNotesDefaultLimitIs50() async throws {
        // Provider returns 100 notes, default limit should return 50
        mock.listNotesResult = (0..<100).map { ["id": "n\($0)", "title": "Note \($0)"] }
        let handler = try XCTUnwrap(handlers["list_notes"])
        let result = try await handler.handle(arguments: nil)
        let text = result.content.first?.text ?? ""
        let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        let notes = json?["notes"] as? [[String: Any]]
        XCTAssertEqual(notes?.count, 50)
        XCTAssertEqual(json?["total"] as? Int, 100)
        XCTAssertEqual(json?["limit"] as? Int, 50)
        XCTAssertEqual(json?["offset"] as? Int, 0)
    }

    func testListNotesPaginationWithLimitAndOffset() async throws {
        mock.listNotesResult = (0..<10).map { ["id": "n\($0)", "title": "Note \($0)"] }
        let handler = try XCTUnwrap(handlers["list_notes"])
        let result = try await handler.handle(arguments: [
            "limit": .int(3),
            "offset": .int(5)
        ])
        let text = result.content.first?.text ?? ""
        let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        let notes = json?["notes"] as? [[String: Any]]
        XCTAssertEqual(notes?.count, 3)
        XCTAssertEqual(json?["total"] as? Int, 10)
        XCTAssertEqual(json?["offset"] as? Int, 5)
        // First note should be n5 (offset=5)
        XCTAssertEqual(notes?.first?["id"] as? String, "n5")
    }

    // MARK: - read_note

    func testReadNoteCallsProvider() async throws {
        mock.readNoteResult = ["id": "n1", "title": "Hello", "body": "World"]
        let handler = try XCTUnwrap(handlers["read_note"])
        let result = try await handler.handle(arguments: ["id": .string("n1")])
        XCTAssertTrue(mock.readNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testReadNoteReturnsContent() async throws {
        mock.readNoteResult = ["id": "note-42", "title": "Meeting Notes", "body": "Discussion points"]
        let handler = try XCTUnwrap(handlers["read_note"])
        let result = try await handler.handle(arguments: ["id": .string("note-42")])
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Meeting Notes") || text.contains("note-42"))
    }

    func testReadNoteMissingIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["read_note"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
    }

    func testReadNoteProviderErrorReturnsErrorResult() async throws {
        mock.readNoteError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Note not found"])
        let handler = try XCTUnwrap(handlers["read_note"])
        let result = try await handler.handle(arguments: ["id": .string("bad-id")])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Note not found") ?? false)
    }

    // MARK: - create_note

    func testCreateNoteCallsProvider() async throws {
        mock.createNoteResult = ["id": "new-1", "title": "New Note"]
        let handler = try XCTUnwrap(handlers["create_note"])
        let result = try await handler.handle(arguments: [
            "title": .string("New Note"),
            "body": .string("Some content")
        ])
        XCTAssertTrue(mock.createNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testCreateNotePassesTitleToProvider() async throws {
        mock.createNoteResult = ["id": "x"]
        let handler = try XCTUnwrap(handlers["create_note"])
        _ = try await handler.handle(arguments: [
            "title": .string("Project Ideas"),
            "body": .string("...")
        ])
        XCTAssertEqual(mock.lastCreateTitle, "Project Ideas")
    }

    func testCreateNoteWithFolderArgument() async throws {
        mock.createNoteResult = ["id": "x"]
        let handler = try XCTUnwrap(handlers["create_note"])
        let result = try await handler.handle(arguments: [
            "title": .string("Work Note"),
            "body": .string("Task details"),
            "folder_name": .string("Work")
        ])
        XCTAssertTrue(mock.createNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testCreateNoteMissingTitleReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["create_note"])
        let result = try await handler.handle(arguments: ["body": .string("content")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testCreateNoteMissingBodyReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["create_note"])
        let result = try await handler.handle(arguments: ["title": .string("Title")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testCreateNoteProviderErrorReturnsErrorResult() async throws {
        mock.createNoteError = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "Folder not found"])
        let handler = try XCTUnwrap(handlers["create_note"])
        let result = try await handler.handle(arguments: [
            "title": .string("Test"),
            "body": .string("Body")
        ])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Folder not found") ?? false)
    }

    // MARK: - update_note

    func testUpdateNoteCallsProvider() async throws {
        mock.updateNoteResult = ["id": "n1", "title": "Updated"]
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "body": .string("New content")
        ])
        XCTAssertTrue(mock.updateNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testUpdateNoteWithAppendTrue() async throws {
        mock.updateNoteResult = ["id": "n1"]
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "body": .string("appended content"),
            "append": .bool(true)
        ])
        XCTAssertTrue(mock.updateNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testUpdateNoteWithAppendFalse() async throws {
        mock.updateNoteResult = ["id": "n1"]
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "body": .string("replacement"),
            "append": .bool(false)
        ])
        XCTAssertTrue(mock.updateNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testUpdateNoteMissingIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: ["body": .string("content")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testUpdateNoteMissingBodyReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: ["id": .string("n1")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testUpdateNoteProviderErrorReturnsErrorResult() async throws {
        mock.updateNoteError = NSError(domain: "test", code: 5, userInfo: [NSLocalizedDescriptionKey: "Note locked"])
        let handler = try XCTUnwrap(handlers["update_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "body": .string("new body")
        ])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Note locked") ?? false)
    }

    // MARK: - search_notes

    func testSearchNotesCallsProvider() async throws {
        mock.searchNotesResult = [["id": "n1", "title": "Meeting"]]
        let handler = try XCTUnwrap(handlers["search_notes"])
        let result = try await handler.handle(arguments: ["query": .string("meeting")])
        XCTAssertTrue(mock.searchNotesCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testSearchNotesReturnsResults() async throws {
        mock.searchNotesResult = [
            ["id": "n1", "title": "Budget Planning"],
            ["id": "n2", "title": "Budget Q4"]
        ]
        let handler = try XCTUnwrap(handlers["search_notes"])
        let result = try await handler.handle(arguments: ["query": .string("budget")])
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Budget") || text.contains("n1"))
    }

    func testSearchNotesMissingQueryReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["search_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
    }

    func testSearchNotesProviderErrorReturnsErrorResult() async throws {
        mock.searchNotesError = NSError(domain: "test", code: 6, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        let handler = try XCTUnwrap(handlers["search_notes"])
        let result = try await handler.handle(arguments: ["query": .string("test")])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Search failed") ?? false)
    }

    // MARK: - delete_note

    func testDeleteNoteCallsProvider() async throws {
        mock.deleteNoteResult = ["id": "n1", "deleted": true]
        let handler = try XCTUnwrap(handlers["delete_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "confirmation": .bool(true)
        ])
        XCTAssertTrue(mock.deleteNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testDeleteNotePassesIdToProvider() async throws {
        mock.deleteNoteResult = ["deleted": true]
        let handler = try XCTUnwrap(handlers["delete_note"])
        _ = try await handler.handle(arguments: [
            "id": .string("note-99"),
            "confirmation": .bool(true)
        ])
        XCTAssertEqual(mock.lastDeleteId, "note-99")
    }

    func testDeleteNoteMissingIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["delete_note"])
        let result = try await handler.handle(arguments: ["confirmation": .bool(true)])
        XCTAssertTrue(result.isError ?? false)
    }

    func testDeleteNoteWithoutConfirmationPassesFalseToProvider() async throws {
        mock.deleteNoteResult = ["deleted": false]
        let handler = try XCTUnwrap(handlers["delete_note"])
        // confirmation absent means false is passed to provider
        _ = try await handler.handle(arguments: ["id": .string("n1")])
        XCTAssertTrue(mock.deleteNoteCalled)
    }

    func testDeleteNoteProviderErrorReturnsErrorResult() async throws {
        mock.deleteNoteError = NSError(domain: "test", code: 7, userInfo: [NSLocalizedDescriptionKey: "Cannot delete locked note"])
        let handler = try XCTUnwrap(handlers["delete_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("locked"),
            "confirmation": .bool(true)
        ])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Cannot delete locked note") ?? false)
    }

    // MARK: - append_to_note

    func testAppendToNoteCallsProvider() async throws {
        mock.appendToNoteResult = ["id": "n1", "title": "My Note"]
        let handler = try XCTUnwrap(handlers["append_to_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "text": .string("Additional content")
        ])
        XCTAssertTrue(mock.appendToNoteCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testAppendToNotePassesCorrectArgs() async throws {
        mock.appendToNoteResult = ["id": "note-42", "title": "T"]
        let handler = try XCTUnwrap(handlers["append_to_note"])
        _ = try await handler.handle(arguments: [
            "id": .string("note-42"),
            "text": .string("appended line")
        ])
        XCTAssertEqual(mock.lastAppendToNoteId, "note-42")
        XCTAssertEqual(mock.lastAppendToNoteText, "appended line")
    }

    func testAppendToNoteMissingIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["append_to_note"])
        let result = try await handler.handle(arguments: ["text": .string("content")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testAppendToNoteMissingTextReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["append_to_note"])
        let result = try await handler.handle(arguments: ["id": .string("n1")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testAppendToNoteProviderErrorReturnsError() async throws {
        mock.appendToNoteError = NSError(domain: "test", code: 8, userInfo: [NSLocalizedDescriptionKey: "Note is locked"])
        let handler = try XCTUnwrap(handlers["append_to_note"])
        let result = try await handler.handle(arguments: [
            "id": .string("n1"),
            "text": .string("text")
        ])
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Note is locked") ?? false)
    }

    // MARK: - find_stale_notes

    func testFindStaleNotesCallsProvider() async throws {
        mock.findStaleNotesResult = [
            ["id": "n1", "title": "Old Note", "modifiedAt": "2023-01-01"],
            ["id": "n2", "title": "Ancient Note", "modifiedAt": "2022-06-15"]
        ]
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(mock.findStaleNotesCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Old Note"))
    }

    func testFindStaleNotesWithDaysParam() async throws {
        mock.findStaleNotesResult = []
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        _ = try await handler.handle(arguments: ["days": .int(180)])
        XCTAssertTrue(mock.findStaleNotesCalled)
        XCTAssertEqual(mock.lastFindStaleNotesDays, 180)
    }

    func testFindStaleNotesEmptyReturnsEmptyArray() async throws {
        mock.findStaleNotesResult = []
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func testFindStaleNotesProviderErrorReturnsError() async throws {
        mock.findStaleNotesError = NSError(domain: "test", code: 9, userInfo: [NSLocalizedDescriptionKey: "Stale search failed"])
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
        XCTAssertTrue(result.content.first?.text?.contains("Stale search failed") ?? false)
    }

    func testFindStaleNotesDefaultLimitIs50() async throws {
        mock.findStaleNotesResult = (0..<80).map { ["id": "n\($0)", "title": "Stale \($0)"] }
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        let result = try await handler.handle(arguments: nil)
        let text = result.content.first?.text ?? ""
        let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        let notes = json?["notes"] as? [[String: Any]]
        XCTAssertEqual(notes?.count, 50)
        XCTAssertEqual(json?["total"] as? Int, 80)
    }

    func testFindStaleNotesPaginationWithLimitAndOffset() async throws {
        mock.findStaleNotesResult = (0..<20).map { ["id": "s\($0)", "title": "Stale \($0)"] }
        let handler = try XCTUnwrap(handlers["find_stale_notes"])
        let result = try await handler.handle(arguments: [
            "limit": .int(5),
            "offset": .int(10)
        ])
        let text = result.content.first?.text ?? ""
        let json = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        let notes = json?["notes"] as? [[String: Any]]
        XCTAssertEqual(notes?.count, 5)
        XCTAssertEqual(json?["total"] as? Int, 20)
        XCTAssertEqual(json?["offset"] as? Int, 10)
        XCTAssertEqual(notes?.first?["id"] as? String, "s10")
    }
}
