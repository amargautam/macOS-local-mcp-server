import Foundation
@testable import MacOSLocalMCP

final class MockNotesProvider: NotesProviding {
    var listNoteFoldersCalled = false
    var listNotesCalled = false
    var readNoteCalled = false
    var createNoteCalled = false
    var updateNoteCalled = false
    var searchNotesCalled = false
    var deleteNoteCalled = false
    var appendToNoteCalled = false
    var findStaleNotesCalled = false

    var listNoteFoldersResult: [[String: Any]] = []
    var listNotesResult: [[String: Any]] = []
    var readNoteResult: [String: Any] = [:]
    var createNoteResult: [String: Any] = [:]
    var updateNoteResult: [String: Any] = [:]
    var searchNotesResult: [[String: Any]] = []
    var deleteNoteResult: [String: Any] = [:]
    var appendToNoteResult: [String: Any] = [:]
    var findStaleNotesResult: [[String: Any]] = []

    var listNoteFoldersError: Error?
    var listNotesError: Error?
    var readNoteError: Error?
    var createNoteError: Error?
    var updateNoteError: Error?
    var searchNotesError: Error?
    var deleteNoteError: Error?
    var appendToNoteError: Error?
    var findStaleNotesError: Error?

    var lastCreateTitle: String?
    var lastDeleteId: String?
    var lastAppendToNoteId: String?
    var lastAppendToNoteText: String?
    var lastFindStaleNotesDays: Int?

    func listNoteFolders() async throws -> [[String: Any]] {
        listNoteFoldersCalled = true
        if let error = listNoteFoldersError { throw error }
        return listNoteFoldersResult
    }

    func listNotes(folderName: String?, sortBy: String?) async throws -> [[String: Any]] {
        listNotesCalled = true
        if let error = listNotesError { throw error }
        return listNotesResult
    }

    func readNote(id: String) async throws -> [String: Any] {
        readNoteCalled = true
        if let error = readNoteError { throw error }
        return readNoteResult
    }

    func createNote(title: String, body: String, folderName: String?) async throws -> [String: Any] {
        createNoteCalled = true
        lastCreateTitle = title
        if let error = createNoteError { throw error }
        return createNoteResult
    }

    func updateNote(id: String, body: String, append: Bool) async throws -> [String: Any] {
        updateNoteCalled = true
        if let error = updateNoteError { throw error }
        return updateNoteResult
    }

    func searchNotes(query: String) async throws -> [[String: Any]] {
        searchNotesCalled = true
        if let error = searchNotesError { throw error }
        return searchNotesResult
    }

    func deleteNote(id: String, confirmation: Bool) async throws -> [String: Any] {
        deleteNoteCalled = true
        lastDeleteId = id
        if let error = deleteNoteError { throw error }
        return deleteNoteResult
    }

    func appendToNote(id: String, text: String) async throws -> [String: Any] {
        appendToNoteCalled = true
        lastAppendToNoteId = id
        lastAppendToNoteText = text
        if let error = appendToNoteError { throw error }
        return appendToNoteResult
    }

    func findStaleNotes(days: Int?) async throws -> [[String: Any]] {
        findStaleNotesCalled = true
        lastFindStaleNotesDays = days
        if let error = findStaleNotesError { throw error }
        return findStaleNotesResult
    }
}
