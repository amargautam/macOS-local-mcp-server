import Foundation

/// Implements NotesProviding by executing AppleScript against the macOS Notes.app.
final class NotesBridge: NotesProviding {

    private let executor: ScriptExecuting

    /// Initialize with a script executor. Defaults to the real AppleScriptBridge.
    init(executor: ScriptExecuting = AppleScriptBridge()) {
        self.executor = executor
    }

    // MARK: - NotesProviding

    func listNoteFolders() async throws -> [[String: Any]] {
        let script = """
        tell application "Notes"
            set folderList to {}
            repeat with aFolder in folders
                set folderInfo to {id: (id of aFolder), name: (name of aFolder)}
                set end of folderList to folderInfo
            end repeat
        end tell
        set jsonOutput to "["
        set folderCount to count of folderList
        repeat with i from 1 to folderCount
            set aFolder to item i of folderList
            set folderId to id of aFolder
            set folderName to name of aFolder
            set escapedId to my escapeJSON(folderId as text)
            set escapedName to my escapeJSON(folderName as text)
            set jsonOutput to jsonOutput & "{\\"id\\":\\"" & escapedId & "\\",\\"name\\":\\"" & escapedName & "\\"}"
            if i < folderCount then set jsonOutput to jsonOutput & ","
        end repeat
        return jsonOutput & "]"

        on escapeJSON(str)
            set escapedStr to ""
            repeat with c in characters of str
                set ch to c as text
                if ch is "\\"" then
                    set escapedStr to escapedStr & "\\\\\\""
                else if ch is "\\\\" then
                    set escapedStr to escapedStr & "\\\\\\\\"
                else if ch is return then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is linefeed then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is tab then
                    set escapedStr to escapedStr & "\\\\t"
                else
                    set escapedStr to escapedStr & ch
                end if
            end repeat
            return escapedStr
        end escapeJSON
        """
        let output = try executor.executeScript(script)
        return try parseJSONArray(output)
    }

    func listNotes(folderName: String?, sortBy: String?) async throws -> [[String: Any]] {
        let folderFilter: String
        let knownFolder: String?
        if let folderName = folderName {
            let escaped = escapeAppleScriptString(folderName)
            folderFilter = "notes of folder \"\(escaped)\""
            knownFolder = folderName
        } else {
            folderFilter = "notes"
            knownFolder = nil
        }

        let script = """
        tell application "Notes"
            set noteIds to id of \(folderFilter)
            set noteTitles to name of \(folderFilter)
            set noteModDates to modification date of \(folderFilter)
            set noteCreDates to creation date of \(folderFilter)
        end tell
        set output to ""
        set n to count of noteIds
        repeat with i from 1 to n
            set output to output & (item i of noteIds) & "|||" & (item i of noteTitles) & "|||" & ((item i of noteModDates) as text) & "|||" & ((item i of noteCreDates) as text)
            if i < n then set output to output & (ASCII character 10)
        end repeat
        return output
        """
        let raw = try executor.executeScript(script)
        return parseNotesList(from: raw, folderName: knownFolder)
    }

    func readNote(id: String) async throws -> [String: Any] {
        let escaped = escapeAppleScriptString(id)
        let script = """
        tell application "Notes"
            set targetNote to note id "\(escaped)"
            set noteId to id of targetNote as text
            set noteTitle to name of targetNote as text
            set noteBody to plaintext of targetNote as text
            set noteContainer to container of targetNote
            set noteFolder to name of noteContainer
            set noteModified to modification date of targetNote as text
            set noteCreated to creation date of targetNote as text
        end tell
        set escapedId to my escapeJSON(noteId)
        set escapedTitle to my escapeJSON(noteTitle)
        set escapedBody to my escapeJSON(noteBody)
        set escapedFolder to my escapeJSON(noteFolder)
        set escapedModified to my escapeJSON(noteModified)
        set escapedCreated to my escapeJSON(noteCreated)
        return "{\\"id\\":\\"" & escapedId & "\\",\\"title\\":\\"" & escapedTitle & "\\",\\"body\\":\\"" & escapedBody & "\\",\\"folder\\":\\"" & escapedFolder & "\\",\\"modifiedAt\\":\\"" & escapedModified & "\\",\\"createdAt\\":\\"" & escapedCreated & "\\"}"

        on escapeJSON(str)
            set escapedStr to ""
            repeat with c in characters of str
                set ch to c as text
                if ch is "\\"" then
                    set escapedStr to escapedStr & "\\\\\\""
                else if ch is "\\\\" then
                    set escapedStr to escapedStr & "\\\\\\\\"
                else if ch is return then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is linefeed then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is tab then
                    set escapedStr to escapedStr & "\\\\t"
                else
                    set escapedStr to escapedStr & ch
                end if
            end repeat
            return escapedStr
        end escapeJSON
        """
        let output = try executor.executeScript(script)
        return try parseJSONObject(output)
    }

    func createNote(title: String, body: String, folderName: String?) async throws -> [String: Any] {
        let escapedTitle = escapeAppleScriptString(title)
        let escapedBody = escapeAppleScriptString(body)

        let targetContainer: String
        if let folderName = folderName {
            let escapedFolder = escapeAppleScriptString(folderName)
            targetContainer = "folder \"\(escapedFolder)\""
        } else {
            targetContainer = "default account"
        }

        let script = """
        tell application "Notes"
            set newNote to make new note at \(targetContainer) with properties {name: "\(escapedTitle)", body: "\(escapedBody)"}
            set noteId to id of newNote as text
            set noteTitle to name of newNote as text
            set noteContainer to container of newNote
            set noteFolder to name of noteContainer
            set noteCreated to creation date of newNote as text
        end tell
        set escapedId to my escapeJSON(noteId)
        set escapedTitle to my escapeJSON(noteTitle)
        set escapedFolder to my escapeJSON(noteFolder)
        set escapedCreated to my escapeJSON(noteCreated)
        return "{\\"id\\":\\"" & escapedId & "\\",\\"title\\":\\"" & escapedTitle & "\\",\\"folder\\":\\"" & escapedFolder & "\\",\\"createdAt\\":\\"" & escapedCreated & "\\"}"

        on escapeJSON(str)
            set escapedStr to ""
            repeat with c in characters of str
                set ch to c as text
                if ch is "\\"" then
                    set escapedStr to escapedStr & "\\\\\\""
                else if ch is "\\\\" then
                    set escapedStr to escapedStr & "\\\\\\\\"
                else if ch is return then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is linefeed then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is tab then
                    set escapedStr to escapedStr & "\\\\t"
                else
                    set escapedStr to escapedStr & ch
                end if
            end repeat
            return escapedStr
        end escapeJSON
        """
        let output = try executor.executeScript(script)
        return try parseJSONObject(output)
    }

    func updateNote(id: String, body: String, append: Bool) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)
        let escapedBody = escapeAppleScriptString(body)

        let bodyAssignment: String
        if append {
            bodyAssignment = """
            set currentBody to plaintext of targetNote
            set body of targetNote to currentBody & "\\n" & "\(escapedBody)"
            """
        } else {
            bodyAssignment = """
            set body of targetNote to "\(escapedBody)"
            """
        }

        let script = """
        tell application "Notes"
            set targetNote to note id "\(escapedId)"
            \(bodyAssignment)
            set noteId to id of targetNote as text
            set noteTitle to name of targetNote as text
            set noteContainer to container of targetNote
            set noteFolder to name of noteContainer
            set noteModified to modification date of targetNote as text
        end tell
        set escapedId to my escapeJSON(noteId)
        set escapedTitle to my escapeJSON(noteTitle)
        set escapedFolder to my escapeJSON(noteFolder)
        set escapedModified to my escapeJSON(noteModified)
        return "{\\"id\\":\\"" & escapedId & "\\",\\"title\\":\\"" & escapedTitle & "\\",\\"folder\\":\\"" & escapedFolder & "\\",\\"modifiedAt\\":\\"" & escapedModified & "\\"}"

        on escapeJSON(str)
            set escapedStr to ""
            repeat with c in characters of str
                set ch to c as text
                if ch is "\\"" then
                    set escapedStr to escapedStr & "\\\\\\""
                else if ch is "\\\\" then
                    set escapedStr to escapedStr & "\\\\\\\\"
                else if ch is return then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is linefeed then
                    set escapedStr to escapedStr & "\\\\n"
                else if ch is tab then
                    set escapedStr to escapedStr & "\\\\t"
                else
                    set escapedStr to escapedStr & ch
                end if
            end repeat
            return escapedStr
        end escapeJSON
        """
        let output = try executor.executeScript(script)
        return try parseJSONObject(output)
    }

    func searchNotes(query: String) async throws -> [[String: Any]] {
        let script = """
        tell application "Notes"
            set noteIds to id of notes
            set noteTitles to name of notes
            set noteBodies to plaintext of notes
        end tell
        set output to ""
        set n to count of noteIds
        repeat with i from 1 to n
            set output to output & (item i of noteIds) & "|||" & (item i of noteTitles) & "|||" & (item i of noteBodies)
            if i < n then set output to output & (ASCII character 10)
        end repeat
        return output
        """
        let raw = try executor.executeScript(script)
        return filterSearchResults(from: raw, query: query)
    }

    func deleteNote(id: String, confirmation: Bool) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)

        guard confirmation else {
            return ["id": id, "deleted": false, "error": "confirmation required"]
        }

        let script = """
        tell application "Notes"
            set targetNote to note id "\(escapedId)"
            set noteId to id of targetNote as text
            delete targetNote
        end tell
        return "{\\"id\\":\\"" & noteId & "\\",\\"deleted\\":true}"
        """
        let output = try executor.executeScript(script)
        return try parseJSONObject(output)
    }

    // MARK: - appendToNote

    func appendToNote(id: String, text: String) async throws -> [String: Any] {
        return try await updateNote(id: id, body: text, append: true)
    }

    // MARK: - findStaleNotes

    func findStaleNotes(days: Int?) async throws -> [[String: Any]] {
        let daysBack = days ?? 90

        let script = """
        tell application "Notes"
            set noteIds to id of notes
            set noteTitles to name of notes
            set noteModDates to modification date of notes
        end tell
        set output to ""
        set n to count of noteIds
        repeat with i from 1 to n
            set output to output & (item i of noteIds) & "|||" & (item i of noteTitles) & "|||" & ((item i of noteModDates) as text)
            if i < n then set output to output & (ASCII character 10)
        end repeat
        return output
        """
        let raw = try executor.executeScript(script)
        return filterStaleNotes(from: raw, daysBack: daysBack)
    }

    // MARK: - Private Helpers

    /// Escape a string for safe insertion into an AppleScript literal.
    private func escapeAppleScriptString(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    /// Parse delimiter-separated note listing into [[String: Any]].
    /// Format per line: id|||title|||modifiedAt|||createdAt
    func parseNotesList(from raw: String, folderName: String?) -> [[String: Any]] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return normalized
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 2 else { return nil }
                var entry: [String: Any] = ["id": parts[0], "title": parts[1]]
                if let folder = folderName { entry["folder"] = folder }
                if parts.count >= 3 { entry["modifiedAt"] = parts[2] }
                if parts.count >= 4 { entry["createdAt"] = parts[3] }
                return entry
            }
    }

    /// Filter search results from batch note data.
    /// Format per line: id|||title|||body
    func filterSearchResults(from raw: String, query: String) -> [[String: Any]] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let lowercaseQuery = query.lowercased()
        return normalized
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 2 else { return nil }
                let title = parts[1]
                let body = parts.count >= 3 ? parts[2] : ""
                guard title.lowercased().contains(lowercaseQuery) || body.lowercased().contains(lowercaseQuery) else {
                    return nil
                }
                return ["id": parts[0], "title": title]
            }
    }

    /// Filter stale notes from batch note data.
    /// Format per line: id|||title|||modifiedAt
    func filterStaleNotes(from raw: String, daysBack: Int) -> [[String: Any]] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(daysBack) * 86400)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // macOS AppleScript date format: "Tuesday, February 17, 2026 at 8:15:07 AM"
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
        return normalized
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 3 else { return nil }
                let dateStr = parts[2].trimmingCharacters(in: .whitespaces)
                // Strip narrow no-break spaces that macOS inserts
                let cleaned = dateStr.replacingOccurrences(of: "\u{202F}", with: " ")
                guard let modDate = formatter.date(from: cleaned), modDate < cutoff else {
                    return nil
                }
                return ["id": parts[0], "title": parts[1], "modifiedAt": parts[2]]
            }
    }

    /// Parse a JSON array string into [[String: Any]].
    private func parseJSONArray(_ jsonString: String) throws -> [[String: Any]] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw AppleScriptError.parseError("Cannot convert output to data")
        }
        do {
            guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw AppleScriptError.parseError("Expected JSON array, got something else")
            }
            return array
        } catch {
            throw AppleScriptError.parseError("JSON parse error: \(error.localizedDescription)")
        }
    }

    /// Parse a JSON object string into [String: Any].
    private func parseJSONObject(_ jsonString: String) throws -> [String: Any] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw AppleScriptError.parseError("Cannot convert output to data")
        }
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AppleScriptError.parseError("Expected JSON object, got something else")
            }
            return dict
        } catch {
            throw AppleScriptError.parseError("JSON parse error: \(error.localizedDescription)")
        }
    }
}
