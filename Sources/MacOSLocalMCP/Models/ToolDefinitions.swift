import Foundation

/// Access level classification for tools.
enum ToolAccessLevel: String {
    case read
    case write
}

/// Registry of all MCP tool definitions with their names, descriptions, and parameter schemas.
/// This is what gets returned by the tools/list method.
enum ToolDefinitions {

    /// Returns all tool definitions for all modules, with annotations attached.
    static var allTools: [MCPToolDefinition] {
        var tools: [MCPToolDefinition] = []
        tools.append(contentsOf: reminderTools)
        tools.append(contentsOf: calendarTools)
        tools.append(contentsOf: contactTools)
        tools.append(contentsOf: mailTools)
        tools.append(contentsOf: messagesTools)
        tools.append(contentsOf: notesTools)
        tools.append(contentsOf: safariTools)
        tools.append(contentsOf: finderTools)
        tools.append(contentsOf: shortcutsTools)
        tools.append(contentsOf: crossAppTools)
        return tools.map { tool in
            MCPToolDefinition(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema,
                annotations: annotations(for: tool.name)
            )
        }
    }

    /// Returns tool definitions filtered by module and read/write access levels.
    static func enabledTools(config: ConfigManager) -> [MCPToolDefinition] {
        return allTools.filter { tool in
            guard let module = toolToModule[tool.name] else { return false }
            let level = toolAccessLevel[tool.name] ?? .write
            return config.isToolAccessEnabled(module: module, accessLevel: level)
        }
    }

    /// Mapping from tool name to the module it belongs to.
    static let toolToModule: [String: String] = {
        var mapping: [String: String] = [:]
        for tool in reminderTools { mapping[tool.name] = "reminders" }
        for tool in calendarTools { mapping[tool.name] = "calendar" }
        for tool in contactTools { mapping[tool.name] = "contacts" }
        for tool in mailTools { mapping[tool.name] = "mail" }
        for tool in messagesTools { mapping[tool.name] = "messages" }
        for tool in notesTools { mapping[tool.name] = "notes" }
        for tool in safariTools { mapping[tool.name] = "safari" }
        for tool in finderTools { mapping[tool.name] = "finder" }
        for tool in shortcutsTools { mapping[tool.name] = "shortcuts" }
        for tool in crossAppTools { mapping[tool.name] = "crossapp" }
        return mapping
    }()

    /// Tools considered destructive (delete, send, execute — irreversible actions).
    static let destructiveTools: Set<String> = [
        "delete_event",
        "delete_note",
        "close_tab",
        "send_message",
        "send_draft",
        "run_shortcut",
        "complete_reminder",
        "bulk_decline_events",
        "bulk_archive_messages",
        "delete_bookmark",
        "close_tabs_matching",
        "delete_contact",
        "merge_contacts",
    ]

    /// Build annotations for a tool based on its access level and destructiveness.
    static func annotations(for toolName: String) -> MCPToolAnnotations {
        let level = toolAccessLevel[toolName] ?? .write
        let isDestructive = destructiveTools.contains(toolName)
        switch level {
        case .read:
            return MCPToolAnnotations(readOnlyHint: true, destructiveHint: false)
        case .write:
            return MCPToolAnnotations(readOnlyHint: false, destructiveHint: isDestructive)
        }
    }

    /// Mapping from tool name to its access level (read or write).
    static let toolAccessLevel: [String: ToolAccessLevel] = [
        // Reminders
        "list_reminder_lists": .read,
        "list_reminders": .read,
        "create_reminder": .write,
        "update_reminder": .write,
        "complete_reminder": .write,
        "search_reminders": .read,
        "move_reminder": .write,
        "bulk_move_reminders": .write,
        // Calendar
        "list_calendars": .read,
        "list_events": .read,
        "create_event": .write,
        "update_event": .write,
        "delete_event": .write,
        "check_availability": .read,
        "search_events": .read,
        "find_conflicts": .read,
        "find_gaps": .read,
        "get_calendar_stats": .read,
        "bulk_decline_events": .write,
        // Contacts
        "search_contacts": .read,
        "get_contact": .read,
        "create_contact": .write,
        "update_contact": .write,
        "list_contact_groups": .read,
        "get_contacts_in_group": .read,
        "find_incomplete_contacts": .read,
        "delete_contact": .write,
        "bulk_update_contacts": .write,
        "list_all_contacts": .read,
        "merge_contacts": .write,
        "create_contact_group": .write,
        "add_contact_to_group": .write,
        // Mail
        "list_mailboxes": .read,
        "list_recent_mail": .read,
        "search_mail": .read,
        "read_mail": .read,
        "create_draft": .write,
        "send_draft": .write,
        "move_message": .write,
        "flag_message": .write,
        "find_unanswered_mail": .read,
        "find_threads_awaiting_reply": .read,
        "list_senders_by_frequency": .read,
        "bulk_archive_messages": .write,
        // Messages
        "list_conversations": .read,
        "read_conversation": .read,
        "send_message": .write,
        "search_messages": .read,
        // Notes
        "list_note_folders": .read,
        "list_notes": .read,
        "read_note": .read,
        "create_note": .write,
        "update_note": .write,
        "search_notes": .read,
        "delete_note": .write,
        "append_to_note": .write,
        "find_stale_notes": .read,
        // Safari
        "list_open_tabs": .read,
        "list_reading_list": .read,
        "search_bookmarks": .read,
        "search_history": .read,
        "close_tab": .write,
        "add_to_reading_list": .write,
        "add_bookmark": .write,
        "delete_bookmark": .write,
        "list_bookmark_folders": .read,
        "create_bookmark_folder": .write,
        "find_duplicate_tabs": .read,
        "close_tabs_matching": .write,
        "get_tab_content": .read,
        "new_tab": .write,
        "reload_tab": .write,
        // Finder
        "spotlight_search": .read,
        "spotlight_search_content": .read,
        "get_file_metadata": .read,
        "set_finder_tags": .write,
        "list_finder_tags": .read,
        "get_tagged_files": .read,
        // Shortcuts
        "list_shortcuts": .read,
        "run_shortcut": .write,
        "get_shortcut_details": .read,
        // CrossApp
        "meeting_context": .read,
        "contact_360": .read,
    ]

    // MARK: - Reminders

    static let reminderTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_reminder_lists",
            description: "List all reminder lists (categories) in the Reminders app.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "list_reminders",
            description: "List reminders, optionally filtered by list, date range, completion status, or priority.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "list_name": MCPToolParameter(type: "string", description: "Filter by reminder list name"),
                    "due_date_start": MCPToolParameter(type: "string", description: "Start of due date range (ISO 8601)"),
                    "due_date_end": MCPToolParameter(type: "string", description: "End of due date range (ISO 8601)"),
                    "is_completed": MCPToolParameter(type: "boolean", description: "Filter by completion status"),
                    "priority": MCPToolParameter(type: "integer", description: "Filter by priority (0=none, 1=high, 5=medium, 9=low)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "create_reminder",
            description: "Create a new reminder with optional due date, priority, and list assignment.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "title": MCPToolParameter(type: "string", description: "Title of the reminder"),
                    "notes": MCPToolParameter(type: "string", description: "Additional notes"),
                    "due_date": MCPToolParameter(type: "string", description: "Due date (ISO 8601)"),
                    "priority": MCPToolParameter(type: "integer", description: "Priority (0=none, 1=high, 5=medium, 9=low)"),
                    "list_name": MCPToolParameter(type: "string", description: "Name of the reminder list")
                ],
                required: ["title"]
            )
        ),
        MCPToolDefinition(
            name: "update_reminder",
            description: "Update an existing reminder's properties.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Reminder ID"),
                    "title": MCPToolParameter(type: "string", description: "New title"),
                    "notes": MCPToolParameter(type: "string", description: "New notes"),
                    "due_date": MCPToolParameter(type: "string", description: "New due date (ISO 8601)"),
                    "priority": MCPToolParameter(type: "integer", description: "New priority"),
                    "is_completed": MCPToolParameter(type: "boolean", description: "Mark as completed or not")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "complete_reminder",
            description: "Mark a reminder as completed.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Reminder ID to complete")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "search_reminders",
            description: "Search reminders by text query across titles and notes.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "move_reminder",
            description: "Move a reminder to a different list.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Reminder ID"),
                    "to_list": MCPToolParameter(type: "string", description: "Target reminder list name")
                ],
                required: ["id", "to_list"]
            )
        ),
        MCPToolDefinition(
            name: "bulk_move_reminders",
            description: "Move multiple reminders to a different list.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "ids": MCPToolParameter(type: "array", description: "Reminder IDs to move", items: MCPToolParameterItems(type: "string")),
                    "to_list": MCPToolParameter(type: "string", description: "Target reminder list name")
                ],
                required: ["ids", "to_list"]
            )
        ),
    ]

    // MARK: - Calendar

    static let calendarTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_calendars",
            description: "List all available calendars.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "list_events",
            description: "List calendar events within a date range, optionally filtered by calendar.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)"),
                    "calendar_name": MCPToolParameter(type: "string", description: "Filter by calendar name")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "create_event",
            description: "Create a new calendar event.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "title": MCPToolParameter(type: "string", description: "Event title"),
                    "start_date": MCPToolParameter(type: "string", description: "Start date/time (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date/time (ISO 8601)"),
                    "is_all_day": MCPToolParameter(type: "boolean", description: "Whether the event is all-day"),
                    "location": MCPToolParameter(type: "string", description: "Event location"),
                    "notes": MCPToolParameter(type: "string", description: "Event notes"),
                    "calendar_name": MCPToolParameter(type: "string", description: "Calendar to create event in")
                ],
                required: ["title", "start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "update_event",
            description: "Update an existing calendar event.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Event ID"),
                    "title": MCPToolParameter(type: "string", description: "New title"),
                    "start_date": MCPToolParameter(type: "string", description: "New start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "New end date (ISO 8601)"),
                    "location": MCPToolParameter(type: "string", description: "New location"),
                    "notes": MCPToolParameter(type: "string", description: "New notes")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "delete_event",
            description: "Delete a calendar event. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Event ID to delete"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm deletion")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "check_availability",
            description: "Check calendar availability for a given time range.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "search_events",
            description: "Search calendar events by text query.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "find_conflicts",
            description: "Find overlapping calendar events in a date range.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "find_gaps",
            description: "Find free time gaps in a date range.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)"),
                    "min_minutes": MCPToolParameter(type: "integer", description: "Minimum gap duration in minutes (default 30)")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "get_calendar_stats",
            description: "Get calendar statistics for a date range (total events, hours booked, busiest day).",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "bulk_decline_events",
            description: "Delete multiple calendar events at once. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "ids": MCPToolParameter(type: "array", description: "Event IDs to delete", items: MCPToolParameterItems(type: "string")),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm deletion")
                ],
                required: ["ids", "confirmation"]
            )
        ),
    ]

    // MARK: - Contacts

    static let contactTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "search_contacts",
            description: "Search contacts by name, email, phone, or company.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "get_contact",
            description: "Get full details of a specific contact by ID.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Contact ID")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "create_contact",
            description: "Create a new contact.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "first_name": MCPToolParameter(type: "string", description: "First name"),
                    "last_name": MCPToolParameter(type: "string", description: "Last name"),
                    "email": MCPToolParameter(type: "string", description: "Email address"),
                    "phone": MCPToolParameter(type: "string", description: "Phone number"),
                    "company": MCPToolParameter(type: "string", description: "Company name")
                ],
                required: ["first_name"]
            )
        ),
        MCPToolDefinition(
            name: "update_contact",
            description: "Update an existing contact's information.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Contact ID"),
                    "first_name": MCPToolParameter(type: "string", description: "New first name"),
                    "last_name": MCPToolParameter(type: "string", description: "New last name"),
                    "email": MCPToolParameter(type: "string", description: "New email"),
                    "phone": MCPToolParameter(type: "string", description: "New phone"),
                    "company": MCPToolParameter(type: "string", description: "New company")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "list_contact_groups",
            description: "List all contact groups.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "get_contacts_in_group",
            description: "Get all contacts in a specific group.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "group_name": MCPToolParameter(type: "string", description: "Name of the contact group")
                ],
                required: ["group_name"]
            )
        ),
        MCPToolDefinition(
            name: "find_incomplete_contacts",
            description: "Find contacts missing key fields (email, phone, or company).",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "delete_contact",
            description: "Delete a contact permanently. Requires confirmation: true.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Contact ID to delete"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm deletion")
                ],
                required: ["id", "confirmation"]
            )
        ),
        MCPToolDefinition(
            name: "bulk_update_contacts",
            description: "Update multiple contacts with the same field values. Applies changes to all specified contact IDs.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "ids": MCPToolParameter(type: "array", description: "Array of contact IDs to update"),
                    "fields": MCPToolParameter(type: "object", description: "Fields to update: first_name, last_name, email, phone, company")
                ],
                required: ["ids", "fields"]
            )
        ),
        MCPToolDefinition(
            name: "list_all_contacts",
            description: "List all contacts with optional pagination. Use limit and offset for large contact lists.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "limit": MCPToolParameter(type: "integer", description: "Maximum number of contacts to return"),
                    "offset": MCPToolParameter(type: "integer", description: "Number of contacts to skip (for pagination)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "merge_contacts",
            description: "Merge two contacts. Fields from source fill blanks on target, then source is deleted. Requires confirmation: true.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "source_id": MCPToolParameter(type: "string", description: "ID of contact to merge from (will be deleted)"),
                    "target_id": MCPToolParameter(type: "string", description: "ID of contact to merge into (will be kept)"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm merge")
                ],
                required: ["source_id", "target_id", "confirmation"]
            )
        ),
        MCPToolDefinition(
            name: "create_contact_group",
            description: "Create a new contact group.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "name": MCPToolParameter(type: "string", description: "Name for the new group")
                ],
                required: ["name"]
            )
        ),
        MCPToolDefinition(
            name: "add_contact_to_group",
            description: "Add a contact to an existing group.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "contact_id": MCPToolParameter(type: "string", description: "Contact ID to add"),
                    "group_name": MCPToolParameter(type: "string", description: "Name of the group to add the contact to")
                ],
                required: ["contact_id", "group_name"]
            )
        ),
    ]

    // MARK: - Mail

    static let mailTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_mailboxes",
            description: "List all mail accounts and mailboxes.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "list_recent_mail",
            description: "List recent emails, optionally filtered by mailbox or unread status.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "count": MCPToolParameter(type: "integer", description: "Number of messages to return (default 20)"),
                    "mailbox": MCPToolParameter(type: "string", description: "Filter by mailbox name"),
                    "unread_only": MCPToolParameter(type: "boolean", description: "Only return unread messages")
                ]
            )
        ),
        MCPToolDefinition(
            name: "search_mail",
            description: "Search emails by sender, subject, body, date range, or attachments.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "sender": MCPToolParameter(type: "string", description: "Filter by sender address"),
                    "subject": MCPToolParameter(type: "string", description: "Filter by subject text"),
                    "body": MCPToolParameter(type: "string", description: "Search in body text"),
                    "date_from": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "date_to": MCPToolParameter(type: "string", description: "End date (ISO 8601)"),
                    "mailbox": MCPToolParameter(type: "string", description: "Filter by mailbox"),
                    "has_attachment": MCPToolParameter(type: "boolean", description: "Only messages with attachments")
                ]
            )
        ),
        MCPToolDefinition(
            name: "read_mail",
            description: "Read the full content of a specific email message.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Message ID")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "create_draft",
            description: "Create a new email draft.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "to": MCPToolParameter(type: "array", description: "Recipients", items: MCPToolParameterItems(type: "string")),
                    "cc": MCPToolParameter(type: "array", description: "CC recipients", items: MCPToolParameterItems(type: "string")),
                    "bcc": MCPToolParameter(type: "array", description: "BCC recipients", items: MCPToolParameterItems(type: "string")),
                    "subject": MCPToolParameter(type: "string", description: "Email subject"),
                    "body": MCPToolParameter(type: "string", description: "Email body"),
                    "is_html": MCPToolParameter(type: "boolean", description: "Whether body is HTML")
                ],
                required: ["to", "subject", "body"]
            )
        ),
        MCPToolDefinition(
            name: "send_draft",
            description: "Send an existing email draft. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Draft ID to send"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm sending")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "move_message",
            description: "Move an email message to a different mailbox.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Message ID"),
                    "to_mailbox": MCPToolParameter(type: "string", description: "Destination mailbox name")
                ],
                required: ["id", "to_mailbox"]
            )
        ),
        MCPToolDefinition(
            name: "flag_message",
            description: "Flag or mark a message as read/unread.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Message ID"),
                    "flagged": MCPToolParameter(type: "boolean", description: "Set flagged status"),
                    "read": MCPToolParameter(type: "boolean", description: "Set read status")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "find_unanswered_mail",
            description: "Find received emails that haven't been replied to.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "days": MCPToolParameter(type: "integer", description: "Number of days to look back (default 7)"),
                    "mailbox": MCPToolParameter(type: "string", description: "Filter by mailbox name")
                ]
            )
        ),
        MCPToolDefinition(
            name: "find_threads_awaiting_reply",
            description: "Find email threads where the last message is from someone else (awaiting your reply).",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "days": MCPToolParameter(type: "integer", description: "Number of days to look back (default 7)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "list_senders_by_frequency",
            description: "List email senders ranked by message count.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "days": MCPToolParameter(type: "integer", description: "Number of days to look back (default 30)"),
                    "limit": MCPToolParameter(type: "integer", description: "Maximum number of senders to return (default 20)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "bulk_archive_messages",
            description: "Move multiple email messages to archive. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "ids": MCPToolParameter(type: "array", description: "Message IDs to archive", items: MCPToolParameterItems(type: "string")),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm archiving")
                ],
                required: ["ids", "confirmation"]
            )
        ),
    ]

    // MARK: - Messages

    static let messagesTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_conversations",
            description: "List recent iMessage/SMS conversations.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "count": MCPToolParameter(type: "integer", description: "Number of conversations to return (default 20)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "read_conversation",
            description: "Read messages from a specific conversation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "contact_id": MCPToolParameter(type: "string", description: "Contact identifier (phone or email)"),
                    "count": MCPToolParameter(type: "integer", description: "Number of messages to return (default 50)")
                ],
                required: ["contact_id"]
            )
        ),
        MCPToolDefinition(
            name: "send_message",
            description: "Send an iMessage or SMS. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "to": MCPToolParameter(type: "string", description: "Recipient phone number or email"),
                    "body": MCPToolParameter(type: "string", description: "Message text"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm sending")
                ],
                required: ["to", "body"]
            )
        ),
        MCPToolDefinition(
            name: "search_messages",
            description: "Search through iMessage/SMS history.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
    ]

    // MARK: - Notes

    static let notesTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_note_folders",
            description: "List all note folders/accounts.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "list_notes",
            description: "List notes with pagination. Returns {notes, total, limit, offset}. Default limit 50.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "folder_name": MCPToolParameter(type: "string", description: "Filter by folder name"),
                    "sort_by": MCPToolParameter(type: "string", description: "Sort by: title, modified, created", enum: ["title", "modified", "created"]),
                    "limit": MCPToolParameter(type: "integer", description: "Max notes to return (default 50)"),
                    "offset": MCPToolParameter(type: "integer", description: "Number of notes to skip (default 0)")
                ]
            )
        ),
        MCPToolDefinition(
            name: "read_note",
            description: "Read the full content of a specific note.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Note ID")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "create_note",
            description: "Create a new note.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "title": MCPToolParameter(type: "string", description: "Note title"),
                    "body": MCPToolParameter(type: "string", description: "Note body content"),
                    "folder_name": MCPToolParameter(type: "string", description: "Folder to create note in")
                ],
                required: ["title", "body"]
            )
        ),
        MCPToolDefinition(
            name: "update_note",
            description: "Update an existing note's content.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Note ID"),
                    "body": MCPToolParameter(type: "string", description: "New body content"),
                    "append": MCPToolParameter(type: "boolean", description: "If true, append to existing content instead of replacing")
                ],
                required: ["id", "body"]
            )
        ),
        MCPToolDefinition(
            name: "search_notes",
            description: "Search notes by text query.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "delete_note",
            description: "Delete a note. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Note ID to delete"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm deletion")
                ],
                required: ["id"]
            )
        ),
        MCPToolDefinition(
            name: "append_to_note",
            description: "Append text to an existing note.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "id": MCPToolParameter(type: "string", description: "Note ID"),
                    "text": MCPToolParameter(type: "string", description: "Text to append")
                ],
                required: ["id", "text"]
            )
        ),
        MCPToolDefinition(
            name: "find_stale_notes",
            description: "Find notes not modified in a specified number of days. Returns {notes, total, limit, offset}. Default limit 50.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "days": MCPToolParameter(type: "integer", description: "Number of days since last modification (default 90)"),
                    "limit": MCPToolParameter(type: "integer", description: "Max notes to return (default 50)"),
                    "offset": MCPToolParameter(type: "integer", description: "Number of notes to skip (default 0)")
                ]
            )
        ),
    ]

    // MARK: - Safari

    static let safariTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_open_tabs",
            description: "List all open tabs across Safari windows.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "list_reading_list",
            description: "List all items in the Safari Reading List.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "search_bookmarks",
            description: "Search Safari bookmarks by text query.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "search_history",
            description: "Search Safari browsing history.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Search query text"),
                    "days_back": MCPToolParameter(type: "integer", description: "Number of days to search back (default 7)")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "close_tab",
            description: "Close a Safari tab by index or URL. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "index": MCPToolParameter(type: "integer", description: "Tab index to close"),
                    "url": MCPToolParameter(type: "string", description: "Close tab matching this URL"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm closing")
                ]
            )
        ),
        MCPToolDefinition(
            name: "add_to_reading_list",
            description: "Add a URL to the Safari Reading List.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "url": MCPToolParameter(type: "string", description: "URL to add"),
                    "title": MCPToolParameter(type: "string", description: "Optional title for the reading list item")
                ],
                required: ["url"]
            )
        ),
        MCPToolDefinition(
            name: "add_bookmark",
            description: "Create a new Safari bookmark.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "url": MCPToolParameter(type: "string", description: "URL to bookmark"),
                    "title": MCPToolParameter(type: "string", description: "Bookmark title"),
                    "folder_name": MCPToolParameter(type: "string", description: "Folder to add bookmark to")
                ],
                required: ["url", "title"]
            )
        ),
        MCPToolDefinition(
            name: "delete_bookmark",
            description: "Delete a Safari bookmark by title or URL. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "title": MCPToolParameter(type: "string", description: "Bookmark title to delete"),
                    "url": MCPToolParameter(type: "string", description: "Bookmark URL to delete"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm deletion")
                ]
            )
        ),
        MCPToolDefinition(
            name: "list_bookmark_folders",
            description: "List all Safari bookmark folders.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "create_bookmark_folder",
            description: "Create a new Safari bookmark folder.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "name": MCPToolParameter(type: "string", description: "Folder name to create")
                ],
                required: ["name"]
            )
        ),
        MCPToolDefinition(
            name: "find_duplicate_tabs",
            description: "Find tabs with identical URLs across Safari windows.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "close_tabs_matching",
            description: "Close all Safari tabs matching a URL pattern. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "pattern": MCPToolParameter(type: "string", description: "URL substring to match"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm closing")
                ],
                required: ["pattern", "confirmation"]
            )
        ),
        MCPToolDefinition(
            name: "get_tab_content",
            description: "Get the text content of a Safari tab.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "index": MCPToolParameter(type: "integer", description: "Tab index"),
                    "url": MCPToolParameter(type: "string", description: "Tab URL to match")
                ]
            )
        ),
        MCPToolDefinition(
            name: "new_tab",
            description: "Open a new Safari tab with a URL.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "url": MCPToolParameter(type: "string", description: "URL to open")
                ],
                required: ["url"]
            )
        ),
        MCPToolDefinition(
            name: "reload_tab",
            description: "Reload a specific Safari tab.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "index": MCPToolParameter(type: "integer", description: "Tab index to reload"),
                    "url": MCPToolParameter(type: "string", description: "Tab URL to match")
                ]
            )
        ),
    ]

    // MARK: - Finder

    static let finderTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "spotlight_search",
            description: "Search files using Spotlight metadata queries.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Spotlight search query"),
                    "kind": MCPToolParameter(type: "string", description: "File kind filter (pdf, image, movie, etc.)"),
                    "directory": MCPToolParameter(type: "string", description: "Limit search to directory"),
                    "max_results": MCPToolParameter(type: "integer", description: "Maximum results to return")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "spotlight_search_content",
            description: "Search file contents using Spotlight.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Content search query"),
                    "directory": MCPToolParameter(type: "string", description: "Limit search to directory"),
                    "max_results": MCPToolParameter(type: "integer", description: "Maximum results to return")
                ],
                required: ["query"]
            )
        ),
        MCPToolDefinition(
            name: "get_file_metadata",
            description: "Get detailed metadata for a file (size, dates, type, tags).",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "path": MCPToolParameter(type: "string", description: "File path")
                ],
                required: ["path"]
            )
        ),
        MCPToolDefinition(
            name: "set_finder_tags",
            description: "Set Finder tags on a file or folder.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "path": MCPToolParameter(type: "string", description: "File path"),
                    "tags": MCPToolParameter(type: "array", description: "Tags to set", items: MCPToolParameterItems(type: "string"))
                ],
                required: ["path", "tags"]
            )
        ),
        MCPToolDefinition(
            name: "list_finder_tags",
            description: "List all Finder tags in use.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "get_tagged_files",
            description: "Get all files with a specific Finder tag.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "tag": MCPToolParameter(type: "string", description: "Tag name to search for")
                ],
                required: ["tag"]
            )
        ),
    ]

    // MARK: - Shortcuts

    static let shortcutsTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "list_shortcuts",
            description: "List all available Shortcuts.",
            inputSchema: MCPToolInputSchema(type: "object")
        ),
        MCPToolDefinition(
            name: "run_shortcut",
            description: "Run a Shortcut by name. Requires confirmation.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "name": MCPToolParameter(type: "string", description: "Shortcut name"),
                    "input": MCPToolParameter(type: "string", description: "Input text to pass to the shortcut"),
                    "confirmation": MCPToolParameter(type: "boolean", description: "Must be true to confirm running")
                ],
                required: ["name"]
            )
        ),
        MCPToolDefinition(
            name: "get_shortcut_details",
            description: "Get details about a specific Shortcut.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "name": MCPToolParameter(type: "string", description: "Shortcut name")
                ],
                required: ["name"]
            )
        ),
    ]

    // MARK: - CrossApp

    static let crossAppTools: [MCPToolDefinition] = [
        MCPToolDefinition(
            name: "meeting_context",
            description: "Get upcoming calendar events enriched with contact details for attendees.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "start_date": MCPToolParameter(type: "string", description: "Start date (ISO 8601)"),
                    "end_date": MCPToolParameter(type: "string", description: "End date (ISO 8601)")
                ],
                required: ["start_date", "end_date"]
            )
        ),
        MCPToolDefinition(
            name: "contact_360",
            description: "Get a full 360-degree view of a contact: info, recent emails, messages, and upcoming events.",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: [
                    "query": MCPToolParameter(type: "string", description: "Contact name or search query")
                ],
                required: ["query"]
            )
        ),
    ]

}
