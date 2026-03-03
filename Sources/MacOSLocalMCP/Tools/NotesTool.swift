import Foundation

/// Tool handlers for the Notes module. Bridges MCP tool calls to NotesProviding.
final class NotesTool {

    private let provider: NotesProviding

    /// Initialize with any object conforming to NotesProviding.
    init(provider: NotesProviding) {
        self.provider = provider
    }

    /// Create and return all 9 tool handlers for the Notes module.
    func createHandlers() -> [MCPToolHandler] {
        return [
            listNoteFolders(),
            listNotes(),
            readNote(),
            createNote(),
            updateNote(),
            searchNotes(),
            deleteNote(),
            appendToNote(),
            findStaleNotes()
        ]
    }

    // MARK: - Individual Handlers

    private func listNoteFolders() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_note_folders") { [weak self] _ in
            guard let self = self else { return .error("NotesTool deallocated") }
            do {
                let folders = try await self.provider.listNoteFolders()
                return .text(Self.encodeJSON(folders))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listNotes() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_notes") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            let folderName = args?["folder_name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }
            let sortBy = args?["sort_by"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }
            let limit: Int = args?["limit"].flatMap { if case .int(let v) = $0 { return v } else { return nil } } ?? 50
            let offset: Int = args?["offset"].flatMap { if case .int(let v) = $0 { return v } else { return nil } } ?? 0
            do {
                let allNotes = try await self.provider.listNotes(folderName: folderName, sortBy: sortBy)
                let total = allNotes.count
                let sliced = Array(allNotes.dropFirst(offset).prefix(limit))
                let wrapper: [String: Any] = ["notes": sliced, "total": total, "limit": limit, "offset": offset]
                return .text(Self.encodeJSONObject(wrapper))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func readNote() -> MCPToolHandler {
        ClosureToolHandler(toolName: "read_note") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let id) = args?["id"] else {
                return .error("Missing required parameter: id")
            }
            do {
                let note = try await self.provider.readNote(id: id)
                return .text(Self.encodeJSONObject(note))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func createNote() -> MCPToolHandler {
        ClosureToolHandler(toolName: "create_note") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let title) = args?["title"] else {
                return .error("Missing required parameter: title")
            }
            guard case .string(let body) = args?["body"] else {
                return .error("Missing required parameter: body")
            }
            let folderName = args?["folder_name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }
            do {
                let note = try await self.provider.createNote(title: title, body: body, folderName: folderName)
                return .text(Self.encodeJSONObject(note))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func updateNote() -> MCPToolHandler {
        ClosureToolHandler(toolName: "update_note") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let id) = args?["id"] else {
                return .error("Missing required parameter: id")
            }
            guard case .string(let body) = args?["body"] else {
                return .error("Missing required parameter: body")
            }
            let append: Bool
            if case .bool(let b) = args?["append"] {
                append = b
            } else {
                append = false
            }
            do {
                let note = try await self.provider.updateNote(id: id, body: body, append: append)
                return .text(Self.encodeJSONObject(note))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func searchNotes() -> MCPToolHandler {
        ClosureToolHandler(toolName: "search_notes") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let query) = args?["query"] else {
                return .error("Missing required parameter: query")
            }
            do {
                let notes = try await self.provider.searchNotes(query: query)
                return .text(Self.encodeJSON(notes))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func deleteNote() -> MCPToolHandler {
        ClosureToolHandler(toolName: "delete_note") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let id) = args?["id"] else {
                return .error("Missing required parameter: id")
            }
            let confirmation: Bool
            if case .bool(let b) = args?["confirmation"] {
                confirmation = b
            } else {
                confirmation = false
            }
            do {
                let result = try await self.provider.deleteNote(id: id, confirmation: confirmation)
                return .text(Self.encodeJSONObject(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func appendToNote() -> MCPToolHandler {
        ClosureToolHandler(toolName: "append_to_note") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            guard case .string(let id) = args?["id"] else {
                return .error("Missing required parameter: id")
            }
            guard case .string(let text) = args?["text"] else {
                return .error("Missing required parameter: text")
            }
            do {
                let note = try await self.provider.appendToNote(id: id, text: text)
                return .text(Self.encodeJSONObject(note))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func findStaleNotes() -> MCPToolHandler {
        ClosureToolHandler(toolName: "find_stale_notes") { [weak self] args in
            guard let self = self else { return .error("NotesTool deallocated") }
            let days: Int? = args?["days"].flatMap { if case .int(let v) = $0 { return v } else { return nil } }
            let limit: Int = args?["limit"].flatMap { if case .int(let v) = $0 { return v } else { return nil } } ?? 50
            let offset: Int = args?["offset"].flatMap { if case .int(let v) = $0 { return v } else { return nil } } ?? 0
            do {
                let allNotes = try await self.provider.findStaleNotes(days: days)
                let total = allNotes.count
                let sliced = Array(allNotes.dropFirst(offset).prefix(limit))
                let wrapper: [String: Any] = ["notes": sliced, "total": total, "limit": limit, "offset": offset]
                return .text(Self.encodeJSONObject(wrapper))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - JSON Encoding Helpers

    /// Encode an array of [String: Any] to a JSON string, falling back to a description on error.
    private static func encodeJSON(_ array: [[String: Any]]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    /// Encode a [String: Any] to a JSON string, falling back to a description on error.
    private static func encodeJSONObject(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
