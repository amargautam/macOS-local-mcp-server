import Foundation

/// Handles MCP tool calls for the macOS Mail app.
struct MailTool {
    private let provider: MailProviding

    init(provider: MailProviding) {
        self.provider = provider
    }

    /// Create all twelve MCPToolHandlers for the Mail module.
    func createHandlers() -> [MCPToolHandler] {
        [
            listMailboxesHandler(),
            listRecentMailHandler(),
            searchMailHandler(),
            readMailHandler(),
            createDraftHandler(),
            sendDraftHandler(),
            moveMessageHandler(),
            flagMessageHandler(),
            findUnansweredMailHandler(),
            findThreadsAwaitingReplyHandler(),
            listSendersByFrequencyHandler(),
            bulkArchiveMessagesHandler()
        ]
    }

    // MARK: - Private handler builders

    private func listMailboxesHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_mailboxes") { [provider] _ in
            do {
                let result = try await provider.listMailboxes()
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listRecentMailHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_recent_mail") { [provider] arguments in
            let count: Int = arguments.flatMap { args -> Int? in
                if case .int(let v) = args["count"] { return v } else { return nil }
            } ?? 20

            let mailbox: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["mailbox"] { return v } else { return nil }
            }

            let unreadOnly: Bool = arguments.flatMap { args -> Bool? in
                if case .bool(let v) = args["unread_only"] { return v } else { return nil }
            } ?? false

            do {
                let result = try await provider.listRecentMail(count: count, mailbox: mailbox, unreadOnly: unreadOnly)
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func searchMailHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "search_mail") { [provider] arguments in
            let sender: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["sender"] { return v } else { return nil }
            }

            let subject: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["subject"] { return v } else { return nil }
            }

            let body: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["body"] { return v } else { return nil }
            }

            let mailbox: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["mailbox"] { return v } else { return nil }
            }

            let hasAttachment: Bool? = arguments.flatMap { args -> Bool? in
                if case .bool(let v) = args["has_attachment"] { return v } else { return nil }
            }

            let dateFrom: Date? = arguments.flatMap { args -> Date? in
                guard case .string(let v) = args["date_from"] else { return nil }
                return ISO8601DateFormatter().date(from: v)
            }

            let dateTo: Date? = arguments.flatMap { args -> Date? in
                guard case .string(let v) = args["date_to"] else { return nil }
                return ISO8601DateFormatter().date(from: v)
            }

            do {
                let result = try await provider.searchMail(
                    sender: sender,
                    subject: subject,
                    body: body,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    mailbox: mailbox,
                    hasAttachment: hasAttachment
                )
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func readMailHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "read_mail") { [provider] arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            do {
                let result = try await provider.readMail(id: id)
                return try encodeDictionary(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func createDraftHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "create_draft") { [provider] arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: to, subject, body")
            }

            // Required: to (array of strings)
            guard case .array(let toItems) = args["to"] else {
                return .error("Missing required parameter: to")
            }
            let to: [String] = toItems.compactMap {
                if case .string(let s) = $0 { return s } else { return nil }
            }

            // Required: subject
            guard case .string(let subject) = args["subject"] else {
                return .error("Missing required parameter: subject")
            }

            // Required: body
            guard case .string(let body) = args["body"] else {
                return .error("Missing required parameter: body")
            }

            // Optional: cc
            let cc: [String]? = {
                guard case .array(let items) = args["cc"] else { return nil }
                let strings = items.compactMap { item -> String? in
                    if case .string(let s) = item { return s } else { return nil }
                }
                return strings.isEmpty ? nil : strings
            }()

            // Optional: bcc
            let bcc: [String]? = {
                guard case .array(let items) = args["bcc"] else { return nil }
                let strings = items.compactMap { item -> String? in
                    if case .string(let s) = item { return s } else { return nil }
                }
                return strings.isEmpty ? nil : strings
            }()

            // Optional: is_html
            let isHTML: Bool = {
                if case .bool(let v) = args["is_html"] { return v }
                return false
            }()

            do {
                let result = try await provider.createDraft(
                    to: to,
                    cc: cc,
                    bcc: bcc,
                    subject: subject,
                    body: body,
                    isHTML: isHTML
                )
                return try encodeDictionary(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func sendDraftHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "send_draft") { [provider] arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            let confirmation: Bool = {
                if case .bool(let v) = args["confirmation"] { return v }
                return false
            }()

            do {
                let result = try await provider.sendDraft(id: id, confirmation: confirmation)
                return try encodeDictionary(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func moveMessageHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "move_message") { [provider] arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            guard case .string(let toMailbox) = args["to_mailbox"] else {
                return .error("Missing required parameter: to_mailbox")
            }

            do {
                let result = try await provider.moveMessage(id: id, toMailbox: toMailbox)
                return try encodeDictionary(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func flagMessageHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "flag_message") { [provider] arguments in
            guard let args = arguments, case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }

            let flagged: Bool? = {
                if case .bool(let v) = args["flagged"] { return v }
                return nil
            }()

            let read: Bool? = {
                if case .bool(let v) = args["read"] { return v }
                return nil
            }()

            do {
                let result = try await provider.flagMessage(id: id, flagged: flagged, read: read)
                return try encodeDictionary(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func findUnansweredMailHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "find_unanswered_mail") { [provider] arguments in
            let days: Int? = arguments.flatMap { args -> Int? in
                if case .int(let v) = args["days"] { return v } else { return nil }
            }
            let mailbox: String? = arguments.flatMap { args -> String? in
                if case .string(let v) = args["mailbox"] { return v } else { return nil }
            }
            do {
                let result = try await provider.findUnansweredMail(days: days, mailbox: mailbox)
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func findThreadsAwaitingReplyHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "find_threads_awaiting_reply") { [provider] arguments in
            let days: Int? = arguments.flatMap { args -> Int? in
                if case .int(let v) = args["days"] { return v } else { return nil }
            }
            do {
                let result = try await provider.findThreadsAwaitingReply(days: days)
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listSendersByFrequencyHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_senders_by_frequency") { [provider] arguments in
            let days: Int? = arguments.flatMap { args -> Int? in
                if case .int(let v) = args["days"] { return v } else { return nil }
            }
            let limit: Int? = arguments.flatMap { args -> Int? in
                if case .int(let v) = args["limit"] { return v } else { return nil }
            }
            do {
                let result = try await provider.listSendersByFrequency(days: days, limit: limit)
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func bulkArchiveMessagesHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "bulk_archive_messages") { [provider] arguments in
            guard let args = arguments, case .array(let idValues) = args["ids"] else {
                return .error("Missing required parameter: ids")
            }
            let ids = idValues.compactMap { value -> String? in
                guard case .string(let s) = value else { return nil }
                return s
            }
            guard !ids.isEmpty else {
                return .error("ids array must not be empty")
            }
            guard case .bool(let confirm) = args["confirmation"], confirm else {
                return .error("bulk_archive_messages requires confirmation: true")
            }
            do {
                let result = try await provider.bulkArchiveMessages(ids: ids, confirmation: confirm)
                return try encodeArray(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Encoding helpers

    private func encodeArray(_ array: [[String: Any]]) throws -> MCPToolResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonValue = JSONValue.from(arrayOfDictionaries: array)
        let data = try encoder.encode(jsonValue)
        return .text(String(data: data, encoding: .utf8) ?? "[]")
    }

    private func encodeDictionary(_ dict: [String: Any]) throws -> MCPToolResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonValue = JSONValue.from(dictionary: dict)
        let data = try encoder.encode(jsonValue)
        return .text(String(data: data, encoding: .utf8) ?? "{}")
    }
}
