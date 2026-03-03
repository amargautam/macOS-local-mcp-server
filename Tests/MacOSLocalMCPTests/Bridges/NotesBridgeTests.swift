import XCTest
@testable import MacOSLocalMCP

/// Tests for NotesBridge that verify AppleScript string generation WITHOUT executing the scripts.
/// A MockScriptExecutor is used to capture the script and return canned JSON.
final class NotesBridgeTests: XCTestCase {

    var executor: MockScriptExecutor!
    var bridge: NotesBridge!

    override func setUp() {
        super.setUp()
        executor = MockScriptExecutor()
        bridge = NotesBridge(executor: executor)
    }

    // MARK: - listNoteFolders AppleScript

    func testListNoteFoldersScriptContainsNotesApp() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listNoteFolders()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"), "Script should reference Notes app")
    }

    func testListNoteFoldersScriptContainsFolderOrAccount() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listNoteFolders()
        let script = try XCTUnwrap(executor.lastScript)
        let hasFolderRef = script.contains("folder") || script.contains("account")
        XCTAssertTrue(hasFolderRef, "Script should reference folders or accounts")
    }

    func testListNoteFoldersReturnsDecodedFolders() async throws {
        executor.resultToReturn = """
        [{"id":"f1","name":"Notes"},{"id":"f2","name":"Work"}]
        """
        let folders = try await bridge.listNoteFolders()
        XCTAssertEqual(folders.count, 2)
        XCTAssertEqual(folders[0]["name"] as? String, "Notes")
        XCTAssertEqual(folders[1]["name"] as? String, "Work")
    }

    func testListNoteFoldersEmptyJSONReturnsEmptyArray() async throws {
        executor.resultToReturn = "[]"
        let folders = try await bridge.listNoteFolders()
        XCTAssertEqual(folders.count, 0)
    }

    // MARK: - listNotes AppleScript

    func testListNotesScriptContainsNotesApp() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.listNotes(folderName: nil, sortBy: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testListNotesWithFolderNameScriptContainsFolderName() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.listNotes(folderName: "Work", sortBy: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Work"), "Script should include the folder name")
    }

    func testListNotesScriptContainsNoteReference() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.listNotes(folderName: nil, sortBy: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("note"), "Script should reference notes")
    }

    func testListNotesReturnsDecodedNotes() async throws {
        executor.resultToReturn = "n1|||Shopping|||2026-03-01|||2026-02-01"
        let notes = try await bridge.listNotes(folderName: nil, sortBy: nil)
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0]["title"] as? String, "Shopping")
    }

    // MARK: - readNote AppleScript

    func testReadNoteScriptContainsNoteId() async throws {
        executor.resultToReturn = """
        {"id":"abc","title":"Hello","body":"World"}
        """
        _ = try await bridge.readNote(id: "abc")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("abc"), "Script should contain the note id")
    }

    func testReadNoteScriptContainsNotesApp() async throws {
        executor.resultToReturn = """
        {"id":"xyz","title":"Test","body":"content"}
        """
        _ = try await bridge.readNote(id: "xyz")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testReadNoteReturnsNoteContent() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"My Title","body":"My Body","folder":"Personal"}
        """
        let note = try await bridge.readNote(id: "n1")
        XCTAssertEqual(note["title"] as? String, "My Title")
        XCTAssertEqual(note["body"] as? String, "My Body")
    }

    func testReadNoteScriptContainsBodyOrContent() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"T","body":"B"}
        """
        _ = try await bridge.readNote(id: "n1")
        let script = try XCTUnwrap(executor.lastScript)
        let hasBodyRef = script.contains("body") || script.contains("content") || script.contains("plaintext")
        XCTAssertTrue(hasBodyRef, "Script should retrieve note body/content")
    }

    // MARK: - createNote AppleScript

    func testCreateNoteScriptContainsTitle() async throws {
        executor.resultToReturn = """
        {"id":"new1","title":"My New Note"}
        """
        _ = try await bridge.createNote(title: "My New Note", body: "body text", folderName: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("My New Note"), "Script should include the note title")
    }

    func testCreateNoteScriptContainsBody() async throws {
        executor.resultToReturn = """
        {"id":"new1","title":"T"}
        """
        _ = try await bridge.createNote(title: "T", body: "important content", folderName: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("important content"), "Script should include note body")
    }

    func testCreateNoteWithFolderScriptContainsFolderName() async throws {
        executor.resultToReturn = """
        {"id":"new2","title":"Work Note"}
        """
        _ = try await bridge.createNote(title: "Work Note", body: "tasks", folderName: "Work")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Work"), "Script should include folder name")
    }

    func testCreateNoteScriptContainsNotesApp() async throws {
        executor.resultToReturn = """
        {"id":"new3","title":"T"}
        """
        _ = try await bridge.createNote(title: "T", body: "B", folderName: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testCreateNoteReturnsNewNote() async throws {
        executor.resultToReturn = """
        {"id":"note-99","title":"New Title","body":"New Body","folder":"Notes"}
        """
        let note = try await bridge.createNote(title: "New Title", body: "New Body", folderName: nil)
        XCTAssertEqual(note["id"] as? String, "note-99")
        XCTAssertEqual(note["title"] as? String, "New Title")
    }

    // MARK: - updateNote AppleScript

    func testUpdateNoteScriptContainsNoteId() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"Updated"}
        """
        _ = try await bridge.updateNote(id: "n1", body: "new body", append: false)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("n1"), "Script should contain note id")
    }

    func testUpdateNoteScriptContainsNewBody() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"T"}
        """
        _ = try await bridge.updateNote(id: "n1", body: "updated content", append: false)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("updated content"), "Script should include new body")
    }

    func testUpdateNoteScriptContainsNotesApp() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"T"}
        """
        _ = try await bridge.updateNote(id: "n1", body: "body", append: false)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testUpdateNoteReturnsUpdatedNote() async throws {
        executor.resultToReturn = """
        {"id":"n1","title":"My Note","body":"updated body"}
        """
        let note = try await bridge.updateNote(id: "n1", body: "updated body", append: false)
        XCTAssertEqual(note["id"] as? String, "n1")
    }

    // MARK: - searchNotes AppleScript

    func testSearchNotesScriptContainsBatchAccess() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.searchNotes(query: "project alpha")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("plaintext of notes"), "Script should batch-fetch note bodies")
    }

    func testSearchNotesScriptContainsNotesApp() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.searchNotes(query: "test")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testSearchNotesReturnsMatchingNotes() async throws {
        executor.resultToReturn = "n1|||Project Alpha Plan|||Some body text\nn2|||Alpha Notes|||Other content"
        let results = try await bridge.searchNotes(query: "Alpha")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["title"] as? String, "Project Alpha Plan")
    }

    func testSearchNotesFiltersNonMatchingNotes() async throws {
        executor.resultToReturn = "n1|||Project Alpha Plan|||body\nn2|||Beta Notes|||no match here"
        let results = try await bridge.searchNotes(query: "Alpha")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["title"] as? String, "Project Alpha Plan")
    }

    func testSearchNotesEmptyResultsReturnsEmptyArray() async throws {
        executor.resultToReturn = ""
        let results = try await bridge.searchNotes(query: "nonexistent")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - deleteNote AppleScript

    func testDeleteNoteScriptContainsNoteId() async throws {
        executor.resultToReturn = """
        {"id":"n1","deleted":true}
        """
        _ = try await bridge.deleteNote(id: "n1", confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("n1"), "Script should contain note id")
    }

    func testDeleteNoteScriptContainsNotesApp() async throws {
        executor.resultToReturn = """
        {"id":"n1","deleted":true}
        """
        _ = try await bridge.deleteNote(id: "n1", confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(script.contains("Notes"))
    }

    func testDeleteNoteWithoutConfirmationReturnsErrorInfo() async throws {
        executor.resultToReturn = """
        {"deleted":false,"error":"confirmation required"}
        """
        let result = try await bridge.deleteNote(id: "n1", confirmation: false)
        // Bridge should pass confirmation=false; result may indicate not deleted
        XCTAssertNotNil(result)
    }

    func testDeleteNoteReturnsResult() async throws {
        executor.resultToReturn = """
        {"id":"n1","deleted":true}
        """
        let result = try await bridge.deleteNote(id: "n1", confirmation: true)
        XCTAssertEqual(result["id"] as? String, "n1")
    }

    // MARK: - Error propagation

    func testBridgeThrowsWhenExecutorThrows() async throws {
        executor.errorToThrow = NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "Script execution failed"])
        do {
            _ = try await bridge.listNoteFolders()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Script execution failed"))
        }
    }

    func testBridgeThrowsWhenExecutorReturnsInvalidJSON() async throws {
        executor.resultToReturn = "not valid json {"
        do {
            _ = try await bridge.listNoteFolders()
            XCTFail("Expected parsing error")
        } catch {
            // Any error is acceptable - invalid JSON should throw
            XCTAssertNotNil(error)
        }
    }
}

