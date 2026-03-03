import Foundation

/// Concrete implementation of `MailProviding` that drives Mail.app via AppleScript.
final class MailBridge: MailProviding {
    private let scriptRunner: ScriptExecuting

    init(scriptRunner: ScriptExecuting = AppleScriptBridge()) {
        self.scriptRunner = scriptRunner
    }

    // MARK: - listMailboxes

    func listMailboxes() async throws -> [[String: Any]] {
        let script = """
        set output to ""
        tell application "Mail"
            repeat with acct in accounts
                set acctName to name of acct
                repeat with mb in mailboxes of acct
                    set mbName to name of mb
                    set output to output & acctName & "\t" & mbName & "\n"
                end repeat
            end repeat
        end tell
        return output
        """
        let raw = try scriptRunner.executeScript(script)
        return parseTabDelimitedMailboxes(raw)
    }

    private func parseTabDelimitedMailboxes(_ raw: String) -> [[String: Any]] {
        guard !raw.isEmpty else { return [] }
        return raw
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line -> [String: Any] in
                let parts = line.components(separatedBy: "\t")
                return [
                    "account": parts.count > 0 ? parts[0] : "",
                    "name": parts.count > 1 ? parts[1] : ""
                ]
            }
    }

    // MARK: - listRecentMail

    func listRecentMail(count: Int, mailbox: String?, unreadOnly: Bool) async throws -> [[String: Any]] {
        let unreadFilter = unreadOnly ? "whose read status is false" : ""
        let mailboxClause: String
        if let mailbox = mailbox {
            let escaped = escapeAppleScriptString(mailbox)
            mailboxClause = "mailbox \"\(escaped)\" of first account"
        } else {
            mailboxClause = "inbox of first account"
        }

        let script = """
        set output to ""
        tell application "Mail"
            set msgs to (messages of \(mailboxClause) \(unreadFilter))
            set msgCount to count of msgs
            if msgCount > \(count) then set msgCount to \(count)
            repeat with i from 1 to msgCount
                set msg to item i of msgs
                set msgId to message id of msg
                set msgSubject to subject of msg
                set msgFrom to sender of msg
                set msgDate to date sent of msg as string
                set msgRead to read status of msg
                set output to output & msgId & "\t" & msgSubject & "\t" & msgFrom & "\t" & msgDate & "\t" & msgRead & "\n"
            end repeat
        end tell
        return output
        """
        let raw = try scriptRunner.executeScript(script)
        return parseTabDelimitedMessages(raw)
    }

    private func parseTabDelimitedMessages(_ raw: String) -> [[String: Any]] {
        guard !raw.isEmpty else { return [] }
        return raw
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line -> [String: Any] in
                let parts = line.components(separatedBy: "\t")
                var dict: [String: Any] = [:]
                if parts.count > 0 { dict["id"] = parts[0] }
                if parts.count > 1 { dict["subject"] = parts[1] }
                if parts.count > 2 { dict["from"] = parts[2] }
                if parts.count > 3 { dict["date"] = parts[3] }
                if parts.count > 4 { dict["read"] = parts[4] == "true" }
                return dict
            }
    }

    // MARK: - searchMail

    func searchMail(
        sender: String?,
        subject: String?,
        body: String?,
        dateFrom: Date?,
        dateTo: Date?,
        mailbox: String?,
        hasAttachment: Bool?
    ) async throws -> [[String: Any]] {
        // Build filter clauses for whose block
        var clauses: [String] = []
        if let sender = sender {
            clauses.append("sender contains \"\(escapeAppleScriptString(sender))\"")
        }
        if let subject = subject {
            clauses.append("subject contains \"\(escapeAppleScriptString(subject))\"")
        }
        if let hasAttachment = hasAttachment, hasAttachment {
            clauses.append("(count of mail attachments) > 0")
        }

        let whereClause = clauses.isEmpty ? "" : "whose (\(clauses.joined(separator: " and ")))"

        let mailboxClause: String
        if let mailbox = mailbox {
            let escaped = escapeAppleScriptString(mailbox)
            mailboxClause = "mailbox \"\(escaped)\" of first account"
        } else {
            mailboxClause = "inbox of first account"
        }

        let script = """
        set output to ""
        tell application "Mail"
            set msgs to (messages of \(mailboxClause) \(whereClause))
            repeat with msg in msgs
                set msgId to message id of msg
                set msgSubject to subject of msg
                set msgFrom to sender of msg
                set msgDate to date sent of msg as string
                set output to output & msgId & "\t" & msgSubject & "\t" & msgFrom & "\t" & msgDate & "\n"
            end repeat
        end tell
        return output
        """
        let raw = try scriptRunner.executeScript(script)
        return parseTabDelimitedMessages(raw)
    }

    // MARK: - readMail

    func readMail(id: String) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)
        let script = """
        tell application "Mail"
            set theMsg to first message of inbox of first account whose message id is "\(escapedId)"
            set msgSubject to subject of theMsg
            set msgFrom to sender of theMsg
            set msgTo to address of to recipients of theMsg
            set msgDate to date sent of theMsg as string
            set msgBody to content of theMsg
            set msgRead to read status of theMsg
            return msgSubject & "\t" & msgFrom & "\t" & (msgTo as string) & "\t" & msgDate & "\t" & msgBody & "\t" & msgRead
        end tell
        """
        let raw = try scriptRunner.executeScript(script)
        let parts = raw.components(separatedBy: "\t")
        var dict: [String: Any] = ["id": id]
        if parts.count > 0 { dict["subject"] = parts[0] }
        if parts.count > 1 { dict["from"] = parts[1] }
        if parts.count > 2 { dict["to"] = parts[2] }
        if parts.count > 3 { dict["date"] = parts[3] }
        if parts.count > 4 { dict["body"] = parts[4] }
        if parts.count > 5 { dict["read"] = parts[5] == "true" }
        return dict
    }

    // MARK: - createDraft

    func createDraft(to: [String], cc: [String]?, bcc: [String]?, subject: String, body: String, isHTML: Bool) async throws -> [String: Any] {
        let toList = to.map { "\"\(escapeAppleScriptString($0))\"" }.joined(separator: ", ")
        let escapedSubject = escapeAppleScriptString(subject)
        let escapedBody = escapeAppleScriptString(body)

        var ccScript = ""
        if let cc = cc, !cc.isEmpty {
            let ccList = cc.map { "make new to recipient at end of cc recipients with properties {address:\"\(escapeAppleScriptString($0))\"}" }.joined(separator: "\n                ")
            ccScript = ccList
        }

        var bccScript = ""
        if let bcc = bcc, !bcc.isEmpty {
            let bccList = bcc.map { "make new to recipient at end of bcc recipients with properties {address:\"\(escapeAppleScriptString($0))\"}" }.joined(separator: "\n                ")
            bccScript = bccList
        }

        let script = """
        tell application "Mail"
            set newMsg to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)", visible:false}
            tell newMsg
                repeat with toAddr in {\(toList)}
                    make new to recipient at end of to recipients with properties {address:toAddr}
                end repeat
                \(ccScript)
                \(bccScript)
            end tell
            set msgId to message id of newMsg
            return msgId
        end tell
        """
        let draftId = try scriptRunner.executeScript(script)
        return ["id": draftId, "subject": subject]
    }

    // MARK: - sendDraft

    func sendDraft(id: String, confirmation: Bool) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)
        let script = """
        tell application "Mail"
            set theMsg to first message of outbox of first account whose message id is "\(escapedId)"
            send theMsg
            return "\(escapedId)"
        end tell
        """
        let resultId = try scriptRunner.executeScript(script)
        return ["id": resultId.isEmpty ? id : resultId, "sent": true]
    }

    // MARK: - moveMessage

    func moveMessage(id: String, toMailbox: String) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)
        let escapedMailbox = escapeAppleScriptString(toMailbox)
        let script = """
        tell application "Mail"
            set theMsg to first message of inbox of first account whose message id is "\(escapedId)"
            set targetMailbox to mailbox "\(escapedMailbox)" of first account
            move theMsg to targetMailbox
            return "\(escapedId)"
        end tell
        """
        _ = try scriptRunner.executeScript(script)
        return ["id": id, "mailbox": toMailbox]
    }

    // MARK: - flagMessage

    func flagMessage(id: String, flagged: Bool?, read: Bool?) async throws -> [String: Any] {
        let escapedId = escapeAppleScriptString(id)
        var setStatements: [String] = []
        if let flagged = flagged {
            setStatements.append("set flagged status of theMsg to \(flagged)")
        }
        if let read = read {
            setStatements.append("set read status of theMsg to \(read)")
        }
        let setBlock = setStatements.isEmpty ? "" : setStatements.joined(separator: "\n            ")

        let script = """
        tell application "Mail"
            set theMsg to first message of inbox of first account whose message id is "\(escapedId)"
            \(setBlock)
            return "\(escapedId)"
        end tell
        """
        _ = try scriptRunner.executeScript(script)
        var result: [String: Any] = ["id": id]
        if let flagged = flagged { result["flagged"] = flagged }
        if let read = read { result["read"] = read }
        return result
    }

    // MARK: - findUnansweredMail

    func findUnansweredMail(days: Int?, mailbox: String?) async throws -> [[String: Any]] {
        let daysBack = days ?? 7
        let mailboxClause: String
        if let mailbox = mailbox {
            let escaped = escapeAppleScriptString(mailbox)
            mailboxClause = "mailbox \"\(escaped)\" of first account"
        } else {
            mailboxClause = "inbox of first account"
        }

        let script = """
        set cutoffDate to (current date) - (\(daysBack) * days)
        set output to ""
        tell application "Mail"
            set msgs to (messages of \(mailboxClause) whose date sent >= cutoffDate)
            repeat with msg in msgs
                set wasReplied to replied to of msg
                if wasReplied is false then
                    set msgId to message id of msg
                    set msgSubject to subject of msg
                    set msgFrom to sender of msg
                    set msgDate to date sent of msg as string
                    set output to output & msgId & "\t" & msgSubject & "\t" & msgFrom & "\t" & msgDate & "\n"
                end if
            end repeat
        end tell
        return output
        """
        let raw = try scriptRunner.executeScript(script)
        return parseTabDelimitedMessages(raw)
    }

    // MARK: - findThreadsAwaitingReply

    func findThreadsAwaitingReply(days: Int?) async throws -> [[String: Any]] {
        let daysBack = days ?? 7

        let script = """
        set cutoffDate to (current date) - (\(daysBack) * days)
        set output to ""
        tell application "Mail"
            set myAddress to address of account 1
            set msgs to (messages of inbox of first account whose date sent >= cutoffDate)
            repeat with msg in msgs
                set msgSender to sender of msg
                if msgSender does not contain myAddress then
                    set wasReplied to replied to of msg
                    if wasReplied is false then
                        set msgId to message id of msg
                        set msgSubject to subject of msg
                        set msgDate to date sent of msg as string
                        set output to output & msgId & "\t" & msgSubject & "\t" & msgSender & "\t" & msgDate & "\n"
                    end if
                end if
            end repeat
        end tell
        return output
        """
        let raw = try scriptRunner.executeScript(script)
        return parseTabDelimitedMessages(raw).map { dict in
            var updated = dict
            // rename "from" key to "lastSender" for clarity
            if let from = dict["from"] {
                updated["lastSender"] = from
            }
            return updated
        }
    }

    // MARK: - listSendersByFrequency

    func listSendersByFrequency(days: Int?, limit: Int?) async throws -> [[String: Any]] {
        let daysBack = days ?? 30
        let maxResults = limit ?? 20

        let script = """
        set cutoffDate to (current date) - (\(daysBack) * days)
        set output to ""
        tell application "Mail"
            set msgs to (messages of inbox of first account whose date sent >= cutoffDate)
            set senderList to {}
            repeat with msg in msgs
                set msgFrom to sender of msg
                set end of senderList to msgFrom
            end repeat
        end tell
        return (senderList as string)
        """
        let raw = try scriptRunner.executeScript(script)
        // raw is comma-separated sender list from AppleScript list coercion
        let senders = raw
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Count occurrences
        var counts: [String: Int] = [:]
        for sender in senders {
            counts[sender, default: 0] += 1
        }

        // Sort descending by count, apply limit
        let sorted = counts
            .sorted { $0.value > $1.value }
            .prefix(maxResults)
            .map { ["sender": $0.key, "count": $0.value] as [String: Any] }

        return sorted
    }

    // MARK: - bulkArchiveMessages

    func bulkArchiveMessages(ids: [String], confirmation: Bool) async throws -> [[String: Any]] {
        guard confirmation else {
            return ids.map { ["id": $0, "archived": false, "error": "confirmation required"] }
        }

        var results: [[String: Any]] = []
        for id in ids {
            let escapedId = escapeAppleScriptString(id)
            let script = """
            tell application "Mail"
                set theMsg to first message of inbox of first account whose message id is "\(escapedId)"
                set targetMailbox to mailbox "Archive" of first account
                move theMsg to targetMailbox
                return "\(escapedId)"
            end tell
            """
            do {
                _ = try scriptRunner.executeScript(script)
                results.append(["id": id, "archived": true])
            } catch {
                results.append(["id": id, "archived": false, "error": error.localizedDescription])
            }
        }
        return results
    }

    // MARK: - Helpers

    /// Escape a string for safe inclusion in an AppleScript string literal.
    private func escapeAppleScriptString(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
