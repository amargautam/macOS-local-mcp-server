import Foundation

/// Provides MCPToolHandler instances for cross-app tools that aggregate data from multiple modules.
final class CrossAppTool {
    private let calendarProvider: CalendarProviding
    private let contactsProvider: ContactsProviding
    private let mailProvider: MailProviding
    private let messagesProvider: MessagesProviding

    init(
        calendarProvider: CalendarProviding,
        contactsProvider: ContactsProviding,
        mailProvider: MailProviding,
        messagesProvider: MessagesProviding
    ) {
        self.calendarProvider = calendarProvider
        self.contactsProvider = contactsProvider
        self.mailProvider = mailProvider
        self.messagesProvider = messagesProvider
    }

    /// Returns all 2 handler objects for the CrossApp module.
    func createHandlers() -> [MCPToolHandler] {
        [
            meetingContextHandler(),
            contact360Handler()
        ]
    }

    // MARK: - Private helpers

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string) ?? iso8601FormatterBasic.date(from: string)
    }

    static func serialize(dict: [String: Any]) -> MCPToolResult {
        do {
            let jsonValue = JSONValue.from(dictionary: dict)
            let data = try JSONEncoder().encode(jsonValue)
            return .text(String(data: data, encoding: .utf8) ?? "{}")
        } catch {
            return .error("Failed to encode result: \(error.localizedDescription)")
        }
    }

    // MARK: - meeting_context

    private func meetingContextHandler() -> MCPToolHandler {
        let calendar = self.calendarProvider
        let contacts = self.contactsProvider
        return ClosureToolHandler(toolName: "meeting_context") { arguments in
            guard let args = arguments else {
                return .error("Missing required parameters: start_date, end_date")
            }

            guard case .string(let rawStart) = args["start_date"] else {
                return .error("Missing required parameter: start_date")
            }
            guard let startDate = CrossAppTool.parseDate(rawStart) else {
                return .error("Invalid start_date: must be ISO 8601 (e.g. 2026-03-01T00:00:00Z)")
            }

            guard case .string(let rawEnd) = args["end_date"] else {
                return .error("Missing required parameter: end_date")
            }
            guard let endDate = CrossAppTool.parseDate(rawEnd) else {
                return .error("Invalid end_date: must be ISO 8601")
            }

            do {
                // Get events in the range
                let events = try await calendar.listEvents(startDate: startDate, endDate: endDate, calendarName: nil)

                // Build enriched context for each event
                var enrichedEvents: [[String: Any]] = []
                for event in events {
                    var enriched = event

                    // If event has attendee info (title or notes may contain names/emails),
                    // try to look up contacts for them
                    if let title = event["title"] as? String {
                        // Try to find contacts related to the event by searching the title
                        let contactMatches = try await contacts.searchContacts(query: title)
                        if !contactMatches.isEmpty {
                            enriched["relatedContacts"] = contactMatches.map { contact in
                                [
                                    "name": "\(contact["firstName"] as? String ?? "") \(contact["lastName"] as? String ?? "")".trimmingCharacters(in: .whitespaces),
                                    "email": contact["email"] as? String ?? "",
                                    "phone": contact["phone"] as? String ?? "",
                                    "company": contact["company"] as? String ?? ""
                                ]
                            }
                        }
                    }

                    enrichedEvents.append(enriched)
                }

                let result: [String: Any] = [
                    "eventCount": enrichedEvents.count,
                    "startDate": rawStart,
                    "endDate": rawEnd,
                    "events": enrichedEvents
                ]

                return CrossAppTool.serialize(dict: result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - contact_360

    private func contact360Handler() -> MCPToolHandler {
        let contacts = self.contactsProvider
        let mail = self.mailProvider
        let messages = self.messagesProvider
        let calendar = self.calendarProvider
        return ClosureToolHandler(toolName: "contact_360") { arguments in
            guard let args = arguments, case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }

            do {
                // Search for the contact
                let contactResults = try await contacts.searchContacts(query: query)
                guard let contact = contactResults.first else {
                    return .error("No contact found matching: \(query)")
                }

                let contactName = "\(contact["firstName"] as? String ?? "") \(contact["lastName"] as? String ?? "")".trimmingCharacters(in: .whitespaces)

                var result: [String: Any] = [
                    "contact": contact
                ]

                // Get recent emails with this contact
                if !contactName.isEmpty {
                    let recentMail = try await mail.searchMail(
                        sender: contactName, subject: nil, body: nil,
                        dateFrom: nil, dateTo: nil, mailbox: nil, hasAttachment: nil
                    )
                    result["recentEmails"] = Array(recentMail.prefix(10))
                    result["emailCount"] = recentMail.count
                }

                // Get recent messages
                if let phone = contact["phone"] as? String, !phone.isEmpty {
                    let recentMessages = try await messages.searchMessages(query: phone)
                    result["recentMessages"] = Array(recentMessages.prefix(10))
                    result["messageCount"] = recentMessages.count
                } else if !contactName.isEmpty {
                    let recentMessages = try await messages.searchMessages(query: contactName)
                    result["recentMessages"] = Array(recentMessages.prefix(10))
                    result["messageCount"] = recentMessages.count
                }

                // Get upcoming events with this contact
                if !contactName.isEmpty {
                    let upcoming = try await calendar.searchEvents(query: contactName)
                    result["upcomingEvents"] = Array(upcoming.prefix(5))
                    result["eventCount"] = upcoming.count
                }

                return CrossAppTool.serialize(dict: result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }
}
