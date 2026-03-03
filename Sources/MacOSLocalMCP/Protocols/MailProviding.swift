import Foundation

/// Protocol for interacting with the macOS Mail app via AppleScript.
protocol MailProviding {
    func listMailboxes() async throws -> [[String: Any]]
    func listRecentMail(count: Int, mailbox: String?, unreadOnly: Bool) async throws -> [[String: Any]]
    func searchMail(sender: String?, subject: String?, body: String?, dateFrom: Date?, dateTo: Date?, mailbox: String?, hasAttachment: Bool?) async throws -> [[String: Any]]
    func readMail(id: String) async throws -> [String: Any]
    func createDraft(to: [String], cc: [String]?, bcc: [String]?, subject: String, body: String, isHTML: Bool) async throws -> [String: Any]
    func sendDraft(id: String, confirmation: Bool) async throws -> [String: Any]
    func moveMessage(id: String, toMailbox: String) async throws -> [String: Any]
    func flagMessage(id: String, flagged: Bool?, read: Bool?) async throws -> [String: Any]
    func findUnansweredMail(days: Int?, mailbox: String?) async throws -> [[String: Any]]
    func findThreadsAwaitingReply(days: Int?) async throws -> [[String: Any]]
    func listSendersByFrequency(days: Int?, limit: Int?) async throws -> [[String: Any]]
    func bulkArchiveMessages(ids: [String], confirmation: Bool) async throws -> [[String: Any]]
}
