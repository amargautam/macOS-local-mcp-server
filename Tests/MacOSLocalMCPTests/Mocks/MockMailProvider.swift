import Foundation
@testable import MacOSLocalMCP

final class MockMailProvider: MailProviding {
    var listMailboxesCalled = false
    var listRecentMailCalled = false
    var searchMailCalled = false
    var readMailCalled = false
    var createDraftCalled = false
    var sendDraftCalled = false
    var moveMessageCalled = false
    var flagMessageCalled = false
    var findUnansweredMailCalled = false
    var findThreadsAwaitingReplyCalled = false
    var listSendersByFrequencyCalled = false
    var bulkArchiveMessagesCalled = false

    var listMailboxesResult: [[String: Any]] = []
    var listRecentMailResult: [[String: Any]] = []
    var searchMailResult: [[String: Any]] = []
    var readMailResult: [String: Any] = [:]
    var createDraftResult: [String: Any] = [:]
    var sendDraftResult: [String: Any] = [:]
    var moveMessageResult: [String: Any] = [:]
    var flagMessageResult: [String: Any] = [:]
    var findUnansweredMailResult: [[String: Any]] = []
    var findThreadsAwaitingReplyResult: [[String: Any]] = []
    var listSendersByFrequencyResult: [[String: Any]] = []
    var bulkArchiveMessagesResult: [[String: Any]] = []

    var listMailboxesError: Error?
    var listRecentMailError: Error?
    var searchMailError: Error?
    var readMailError: Error?
    var createDraftError: Error?
    var sendDraftError: Error?
    var moveMessageError: Error?
    var flagMessageError: Error?
    var findUnansweredMailError: Error?
    var findThreadsAwaitingReplyError: Error?
    var listSendersByFrequencyError: Error?
    var bulkArchiveMessagesError: Error?

    // Captured arguments
    var lastFindUnansweredMailDays: Int?
    var lastFindUnansweredMailMailbox: String?
    var lastFindThreadsAwaitingReplyDays: Int?
    var lastListSendersByFrequencyDays: Int?
    var lastListSendersByFrequencyLimit: Int?
    var lastBulkArchiveMessagesIds: [String]?
    var lastBulkArchiveMessagesConfirmation: Bool?

    func listMailboxes() async throws -> [[String: Any]] {
        listMailboxesCalled = true
        if let error = listMailboxesError { throw error }
        return listMailboxesResult
    }

    func listRecentMail(count: Int, mailbox: String?, unreadOnly: Bool) async throws -> [[String: Any]] {
        listRecentMailCalled = true
        if let error = listRecentMailError { throw error }
        return listRecentMailResult
    }

    func searchMail(sender: String?, subject: String?, body: String?, dateFrom: Date?, dateTo: Date?, mailbox: String?, hasAttachment: Bool?) async throws -> [[String: Any]] {
        searchMailCalled = true
        if let error = searchMailError { throw error }
        return searchMailResult
    }

    func readMail(id: String) async throws -> [String: Any] {
        readMailCalled = true
        if let error = readMailError { throw error }
        return readMailResult
    }

    func createDraft(to: [String], cc: [String]?, bcc: [String]?, subject: String, body: String, isHTML: Bool) async throws -> [String: Any] {
        createDraftCalled = true
        if let error = createDraftError { throw error }
        return createDraftResult
    }

    func sendDraft(id: String, confirmation: Bool) async throws -> [String: Any] {
        sendDraftCalled = true
        if let error = sendDraftError { throw error }
        return sendDraftResult
    }

    func moveMessage(id: String, toMailbox: String) async throws -> [String: Any] {
        moveMessageCalled = true
        if let error = moveMessageError { throw error }
        return moveMessageResult
    }

    func flagMessage(id: String, flagged: Bool?, read: Bool?) async throws -> [String: Any] {
        flagMessageCalled = true
        if let error = flagMessageError { throw error }
        return flagMessageResult
    }

    func findUnansweredMail(days: Int?, mailbox: String?) async throws -> [[String: Any]] {
        findUnansweredMailCalled = true
        lastFindUnansweredMailDays = days
        lastFindUnansweredMailMailbox = mailbox
        if let error = findUnansweredMailError { throw error }
        return findUnansweredMailResult
    }

    func findThreadsAwaitingReply(days: Int?) async throws -> [[String: Any]] {
        findThreadsAwaitingReplyCalled = true
        lastFindThreadsAwaitingReplyDays = days
        if let error = findThreadsAwaitingReplyError { throw error }
        return findThreadsAwaitingReplyResult
    }

    func listSendersByFrequency(days: Int?, limit: Int?) async throws -> [[String: Any]] {
        listSendersByFrequencyCalled = true
        lastListSendersByFrequencyDays = days
        lastListSendersByFrequencyLimit = limit
        if let error = listSendersByFrequencyError { throw error }
        return listSendersByFrequencyResult
    }

    func bulkArchiveMessages(ids: [String], confirmation: Bool) async throws -> [[String: Any]] {
        bulkArchiveMessagesCalled = true
        lastBulkArchiveMessagesIds = ids
        lastBulkArchiveMessagesConfirmation = confirmation
        if let error = bulkArchiveMessagesError { throw error }
        return bulkArchiveMessagesResult
    }
}
