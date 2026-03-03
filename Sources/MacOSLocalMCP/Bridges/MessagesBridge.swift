import Foundation

/// Concrete implementation of MessagesProviding that drives Messages.app via AppleScript.
final class MessagesBridge: MessagesProviding {

    private let executor: ScriptExecuting

    init(executor: ScriptExecuting = AppleScriptBridge()) {
        self.executor = executor
    }

    // MARK: - listConversations

    func listConversations(count: Int) async throws -> [[String: Any]] {
        let script = listConversationsScript(count: count)
        let raw = try executor.executeScript(script)
        return parseConversations(from: raw)
    }

    // MARK: - readConversation

    func readConversation(contactId: String, count: Int) async throws -> [[String: Any]] {
        let escaped = escapeAppleScriptString(contactId)
        let script = readConversationScript(contactId: escaped, count: count)
        let raw = try executor.executeScript(script)
        return parseMessages(from: raw)
    }

    // MARK: - sendMessage

    func sendMessage(to recipient: String, body: String, confirmation: Bool) async throws -> [String: Any] {
        guard confirmation else {
            throw MessagesError.confirmationRequired
        }
        let escapedTo = escapeAppleScriptString(recipient)
        let escapedBody = escapeAppleScriptString(body)
        let script = sendMessageScript(to: escapedTo, body: escapedBody)
        _ = try executor.executeScript(script)
        return ["status": "sent", "to": recipient]
    }

    // MARK: - searchMessages

    func searchMessages(query: String) async throws -> [[String: Any]] {
        let escaped = escapeAppleScriptString(query)
        let script = searchMessagesScript(query: escaped)
        let raw = try executor.executeScript(script)
        return parseMessages(from: raw)
    }
}

// MARK: - Script Generation

extension MessagesBridge {

    func listConversationsScript(count: Int) -> String {
        """
        do shell script "sqlite3 -separator '|||' ~/Library/Messages/chat.db 'SELECT COALESCE(NULLIF(c.display_name, \\\"\\\"), h.id, c.chat_identifier), COALESCE(m.text, \\\"(attachment)\\\"), datetime(m.date/1000000000 + 978307200, \\\"unixepoch\\\", \\\"localtime\\\") FROM chat c LEFT JOIN chat_handle_join chj ON c.ROWID = chj.chat_id LEFT JOIN handle h ON chj.handle_id = h.ROWID JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id JOIN message m ON cmj.message_id = m.ROWID WHERE m.date = (SELECT MAX(m2.date) FROM chat_message_join cmj2 JOIN message m2 ON cmj2.message_id = m2.ROWID WHERE cmj2.chat_id = c.ROWID) GROUP BY c.ROWID ORDER BY m.date DESC LIMIT \(count);'"
        """
    }

    func readConversationScript(contactId: String, count: Int) -> String {
        """
        do shell script "sqlite3 -separator '|||' ~/Library/Messages/chat.db 'SELECT CASE WHEN m.is_from_me = 1 THEN \\\"Me\\\" ELSE COALESCE(h.id, \\\"Unknown\\\") END, COALESCE(m.text, \\\"(attachment)\\\"), datetime(m.date/1000000000 + 978307200, \\\"unixepoch\\\", \\\"localtime\\\") FROM message m JOIN chat_message_join cmj ON m.ROWID = cmj.message_id JOIN chat c ON cmj.chat_id = c.ROWID LEFT JOIN handle h ON m.handle_id = h.ROWID WHERE c.chat_identifier LIKE \\\"%\(contactId)%\\\" OR c.display_name LIKE \\\"%\(contactId)%\\\" OR h.id LIKE \\\"%\(contactId)%\\\" ORDER BY m.date DESC LIMIT \(count);'"
        """
    }

    func sendMessageScript(to recipient: String, body: String) -> String {
        """
        tell application "Messages"
            set targetService to 1st service whose service type = iMessage
            set targetBuddy to buddy "\(recipient)" of targetService
            send "\(body)" to targetBuddy
        end tell
        """
    }

    func searchMessagesScript(query: String) -> String {
        """
        do shell script "sqlite3 -separator '|||' ~/Library/Messages/chat.db 'SELECT CASE WHEN m.is_from_me = 1 THEN \\\"Me\\\" ELSE COALESCE(h.id, \\\"Unknown\\\") END, COALESCE(m.text, \\\"\\\"), datetime(m.date/1000000000 + 978307200, \\\"unixepoch\\\", \\\"localtime\\\") FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID WHERE m.text LIKE \\\"%\(query)%\\\" ORDER BY m.date DESC LIMIT 50;'"
        """
    }
}

// MARK: - Parsing Helpers

private extension MessagesBridge {

    func parseConversations(from raw: String) -> [[String: Any]] {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 1 else { return nil }
                var entry: [String: Any] = ["contactName": parts[0]]
                if parts.count >= 2 { entry["lastMessage"] = parts[1] }
                if parts.count >= 3 { entry["date"] = parts[2] }
                return entry
            }
    }

    func parseMessages(from raw: String) -> [[String: Any]] {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> [String: Any]? in
                let parts = line.components(separatedBy: "|||")
                guard parts.count >= 2 else { return nil }
                var entry: [String: Any] = ["sender": parts[0], "body": parts[1]]
                if parts.count >= 3 { entry["date"] = parts[2] }
                return entry
            }
    }
}

// MARK: - String Escaping

private extension MessagesBridge {
    /// Escape a string for safe embedding inside an AppleScript string literal.
    func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

// MARK: - MessagesError

enum MessagesError: LocalizedError {
    case confirmationRequired

    var errorDescription: String? {
        switch self {
        case .confirmationRequired:
            return "Sending a message requires confirmation: true"
        }
    }
}
