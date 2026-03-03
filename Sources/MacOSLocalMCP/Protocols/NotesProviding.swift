import Foundation

/// Protocol for interacting with the macOS Notes app via AppleScript.
protocol NotesProviding {
    func listNoteFolders() async throws -> [[String: Any]]
    func listNotes(folderName: String?, sortBy: String?) async throws -> [[String: Any]]
    func readNote(id: String) async throws -> [String: Any]
    func createNote(title: String, body: String, folderName: String?) async throws -> [String: Any]
    func updateNote(id: String, body: String, append: Bool) async throws -> [String: Any]
    func searchNotes(query: String) async throws -> [[String: Any]]
    func deleteNote(id: String, confirmation: Bool) async throws -> [String: Any]
    func appendToNote(id: String, text: String) async throws -> [String: Any]
    func findStaleNotes(days: Int?) async throws -> [[String: Any]]
}
