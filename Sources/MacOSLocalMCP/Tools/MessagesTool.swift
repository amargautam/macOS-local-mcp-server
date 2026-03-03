import Foundation

/// Tool handler factory for Messages.app tools.
/// Wraps a MessagesProviding dependency and creates MCPToolHandler instances.
struct MessagesTool {

    private let provider: MessagesProviding

    init(provider: MessagesProviding) {
        self.provider = provider
    }

    /// Create all four Messages tool handlers.
    func createHandlers() -> [MCPToolHandler] {
        [
            makeListConversationsHandler(),
            makeReadConversationHandler(),
            makeSendMessageHandler(),
            makeSearchMessagesHandler()
        ]
    }

    // MARK: - list_conversations

    private func makeListConversationsHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_conversations") { [provider] arguments in
            let count = arguments?["count"]?.intValue ?? 20
            do {
                let conversations = try await provider.listConversations(count: count)
                return formatConversations(conversations)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - read_conversation

    private func makeReadConversationHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "read_conversation") { [provider] arguments in
            guard let contactId = arguments?["contact_id"]?.stringValue else {
                return .error("Missing required parameter: contact_id")
            }
            let count = arguments?["count"]?.intValue ?? 50
            do {
                let messages = try await provider.readConversation(contactId: contactId, count: count)
                return formatMessages(messages, contactId: contactId)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - send_message

    private func makeSendMessageHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "send_message") { [provider] arguments in
            guard let to = arguments?["to"]?.stringValue else {
                return .error("Missing required parameter: to")
            }
            guard let body = arguments?["body"]?.stringValue else {
                return .error("Missing required parameter: body")
            }
            guard let confirmation = arguments?["confirmation"]?.boolValue, confirmation else {
                return .error("Sending messages requires confirmation: true for safety.")
            }
            do {
                let result = try await provider.sendMessage(to: to, body: body, confirmation: confirmation)
                return formatSendResult(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - search_messages

    private func makeSearchMessagesHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "search_messages") { [provider] arguments in
            guard let query = arguments?["query"]?.stringValue else {
                return .error("Missing required parameter: query")
            }
            do {
                let results = try await provider.searchMessages(query: query)
                return formatSearchResults(results, query: query)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Formatting Helpers

private func formatConversations(_ conversations: [[String: Any]]) -> MCPToolResult {
    if conversations.isEmpty {
        return .text("No conversations found.")
    }
    let lines = conversations.map { formatConversationEntry($0) }
    return .text(lines.joined(separator: "\n\n"))
}

private func formatConversationEntry(_ entry: [String: Any]) -> String {
    var parts: [String] = []
    if let name = entry["contactName"] as? String {
        parts.append("Contact: \(name)")
    }
    if let phone = entry["phoneNumber"] as? String {
        parts.append("Phone: \(phone)")
    }
    if let snippet = entry["lastMessage"] as? String {
        parts.append("Last message: \(snippet)")
    }
    if let date = entry["date"] as? String {
        parts.append("Date: \(date)")
    }
    return parts.joined(separator: "\n")
}

private func formatMessages(_ messages: [[String: Any]], contactId: String) -> MCPToolResult {
    if messages.isEmpty {
        return .text("No messages found for \(contactId).")
    }
    let lines = messages.map { formatMessageEntry($0) }
    return .text(lines.joined(separator: "\n\n"))
}

private func formatMessageEntry(_ entry: [String: Any]) -> String {
    var parts: [String] = []
    if let sender = entry["sender"] as? String {
        parts.append("From: \(sender)")
    }
    if let body = entry["body"] as? String {
        parts.append("Message: \(body)")
    }
    if let date = entry["date"] as? String {
        parts.append("Date: \(date)")
    }
    return parts.joined(separator: "\n")
}

private func formatSendResult(_ result: [String: Any]) -> MCPToolResult {
    var parts: [String] = ["Message sent successfully."]
    if let to = result["to"] as? String {
        parts.append("To: \(to)")
    }
    if let status = result["status"] as? String {
        parts.append("Status: \(status)")
    }
    return .text(parts.joined(separator: "\n"))
}

private func formatSearchResults(_ results: [[String: Any]], query: String) -> MCPToolResult {
    if results.isEmpty {
        return .text("No messages found matching '\(query)'.")
    }
    let lines = results.map { formatMessageEntry($0) }
    return .text("Found \(results.count) message(s) matching '\(query)':\n\n" + lines.joined(separator: "\n\n"))
}

// MARK: - JSONValue helpers (local extensions for MessagesTool)

private extension JSONValue {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
