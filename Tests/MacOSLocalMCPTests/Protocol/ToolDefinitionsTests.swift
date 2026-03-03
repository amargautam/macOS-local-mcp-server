import XCTest
@testable import MacOSLocalMCP

final class ToolDefinitionsTests: XCTestCase {

    // MARK: - allTools

    func testAllToolsNotEmpty() {
        XCTAssertFalse(ToolDefinitions.allTools.isEmpty)
    }

    func testAllToolsContainsExpectedModuleTools() {
        let names = Set(ToolDefinitions.allTools.map { $0.name })
        // Reminders
        XCTAssertTrue(names.contains("list_reminder_lists"))
        XCTAssertTrue(names.contains("create_reminder"))
        XCTAssertTrue(names.contains("search_reminders"))
        XCTAssertTrue(names.contains("move_reminder"))
        XCTAssertTrue(names.contains("bulk_move_reminders"))
        // Calendar
        XCTAssertTrue(names.contains("list_calendars"))
        XCTAssertTrue(names.contains("create_event"))
        XCTAssertTrue(names.contains("check_availability"))
        XCTAssertTrue(names.contains("find_conflicts"))
        XCTAssertTrue(names.contains("find_gaps"))
        XCTAssertTrue(names.contains("get_calendar_stats"))
        XCTAssertTrue(names.contains("bulk_decline_events"))
        // Contacts
        XCTAssertTrue(names.contains("search_contacts"))
        XCTAssertTrue(names.contains("find_incomplete_contacts"))
        // Mail
        XCTAssertTrue(names.contains("list_mailboxes"))
        XCTAssertTrue(names.contains("create_draft"))
        XCTAssertTrue(names.contains("find_unanswered_mail"))
        XCTAssertTrue(names.contains("find_threads_awaiting_reply"))
        XCTAssertTrue(names.contains("list_senders_by_frequency"))
        XCTAssertTrue(names.contains("bulk_archive_messages"))
        // Messages
        XCTAssertTrue(names.contains("send_message"))
        // Notes
        XCTAssertTrue(names.contains("create_note"))
        XCTAssertTrue(names.contains("append_to_note"))
        XCTAssertTrue(names.contains("find_stale_notes"))
        // Safari
        XCTAssertTrue(names.contains("list_open_tabs"))
        XCTAssertTrue(names.contains("add_to_reading_list"))
        XCTAssertTrue(names.contains("add_bookmark"))
        XCTAssertTrue(names.contains("delete_bookmark"))
        XCTAssertTrue(names.contains("list_bookmark_folders"))
        XCTAssertTrue(names.contains("find_duplicate_tabs"))
        XCTAssertTrue(names.contains("new_tab"))
        // Finder
        XCTAssertTrue(names.contains("spotlight_search"))
        // Shortcuts
        XCTAssertTrue(names.contains("list_shortcuts"))
        XCTAssertTrue(names.contains("run_shortcut"))
        // CrossApp
        XCTAssertTrue(names.contains("meeting_context"))
        XCTAssertTrue(names.contains("contact_360"))
    }

    func testAllToolsHaveNonEmptyNames() {
        for tool in ToolDefinitions.allTools {
            XCTAssertFalse(tool.name.isEmpty, "Tool has empty name")
        }
    }

    func testAllToolsHaveNonEmptyDescriptions() {
        for tool in ToolDefinitions.allTools {
            XCTAssertFalse(tool.description.isEmpty, "Tool \(tool.name) has empty description")
        }
    }

    func testAllToolsHaveObjectInputSchema() {
        for tool in ToolDefinitions.allTools {
            XCTAssertEqual(tool.inputSchema.type, "object", "Tool \(tool.name) schema type should be 'object'")
        }
    }

    // MARK: - enabledTools

    func testEnabledToolsWithDefaultReadOnlyConfig() {
        let config = ConfigManager(config: ConfigData.defaults)
        let enabledTools = ToolDefinitions.enabledTools(config: config)
        // Defaults are read-only, so only read-level tools should be enabled
        let readOnlyTools = ToolDefinitions.allTools.filter {
            (ToolDefinitions.toolAccessLevel[$0.name] ?? .write) == .read
        }
        XCTAssertEqual(enabledTools.count, readOnlyTools.count)
    }

    func testEnabledToolsWithAllModulesFullyEnabled() {
        let allEnabled = ConfigData(
            logLevel: "normal", logMaxSizeMB: 10,
            enabledModules: [
                "reminders": .allEnabled, "calendar": .allEnabled, "mail": .allEnabled,
                "messages": .allEnabled, "notes": .allEnabled, "contacts": .allEnabled,
                "safari": .allEnabled, "finder": .allEnabled, "shortcuts": .allEnabled,
                "crossapp": .allEnabled,
            ],
            confirmationRequired: [:]
        )
        let config = ConfigManager(config: allEnabled)
        let enabledTools = ToolDefinitions.enabledTools(config: config)
        XCTAssertEqual(enabledTools.count, ToolDefinitions.allTools.count)
    }

    func testEnabledToolsWithRemindersDisabled() {
        let configData = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [
                "reminders": .allDisabled,
                "calendar": .allEnabled,
                "mail": .allEnabled,
                "messages": .allEnabled,
                "notes": .allEnabled,
                "contacts": .allEnabled,
                "safari": .allEnabled,
                "finder": .allEnabled,
                "shortcuts": .allEnabled,
                "crossapp": .allEnabled,
            ],
            confirmationRequired: [:]
        )
        let config = ConfigManager(config: configData)
        let enabledTools = ToolDefinitions.enabledTools(config: config)
        let enabledNames = Set(enabledTools.map { $0.name })
        XCTAssertFalse(enabledNames.contains("list_reminder_lists"))
        XCTAssertFalse(enabledNames.contains("create_reminder"))
        XCTAssertTrue(enabledNames.contains("list_calendars"))
    }

    func testEnabledToolsWithReadOnlyModule() {
        let configData = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [
                "reminders": .readOnly,
                "calendar": .allEnabled,
                "mail": .allEnabled,
                "messages": .allEnabled,
                "notes": .allEnabled,
                "contacts": .allEnabled,
                "safari": .allEnabled,
                "finder": .allEnabled,
                "shortcuts": .allEnabled,
                "crossapp": .allEnabled,
            ],
            confirmationRequired: [:]
        )
        let config = ConfigManager(config: configData)
        let enabledTools = ToolDefinitions.enabledTools(config: config)
        let enabledNames = Set(enabledTools.map { $0.name })
        // Read tools should be enabled
        XCTAssertTrue(enabledNames.contains("list_reminder_lists"))
        XCTAssertTrue(enabledNames.contains("list_reminders"))
        XCTAssertTrue(enabledNames.contains("search_reminders"))
        // Write tools should be disabled
        XCTAssertFalse(enabledNames.contains("create_reminder"))
        XCTAssertFalse(enabledNames.contains("update_reminder"))
        XCTAssertFalse(enabledNames.contains("complete_reminder"))
    }

    func testEnabledToolsWithAllModulesDisabled() {
        let configData = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [:],
            confirmationRequired: [:]
        )
        let config = ConfigManager(config: configData)
        let enabledTools = ToolDefinitions.enabledTools(config: config)
        XCTAssertTrue(enabledTools.isEmpty)
    }

    // MARK: - toolToModule

    func testToolToModuleMapping() {
        let mapping = ToolDefinitions.toolToModule
        XCTAssertEqual(mapping["list_reminder_lists"], "reminders")
        XCTAssertEqual(mapping["create_reminder"], "reminders")
        XCTAssertEqual(mapping["move_reminder"], "reminders")
        XCTAssertEqual(mapping["list_calendars"], "calendar")
        XCTAssertEqual(mapping["create_event"], "calendar")
        XCTAssertEqual(mapping["find_conflicts"], "calendar")
        XCTAssertEqual(mapping["find_gaps"], "calendar")
        XCTAssertEqual(mapping["search_contacts"], "contacts")
        XCTAssertEqual(mapping["find_incomplete_contacts"], "contacts")
        XCTAssertEqual(mapping["list_mailboxes"], "mail")
        XCTAssertEqual(mapping["find_unanswered_mail"], "mail")
        XCTAssertEqual(mapping["send_message"], "messages")
        XCTAssertEqual(mapping["create_note"], "notes")
        XCTAssertEqual(mapping["append_to_note"], "notes")
        XCTAssertEqual(mapping["list_open_tabs"], "safari")
        XCTAssertEqual(mapping["add_bookmark"], "safari")
        XCTAssertEqual(mapping["new_tab"], "safari")
        XCTAssertEqual(mapping["spotlight_search"], "finder")
        XCTAssertEqual(mapping["list_shortcuts"], "shortcuts")
        XCTAssertEqual(mapping["meeting_context"], "crossapp")
        XCTAssertEqual(mapping["contact_360"], "crossapp")
    }

    func testToolToModuleCoversAllTools() {
        let mapping = ToolDefinitions.toolToModule
        for tool in ToolDefinitions.allTools {
            XCTAssertNotNil(mapping[tool.name], "Tool \(tool.name) missing from toolToModule mapping")
        }
    }

    func testNoDuplicateToolNames() {
        let names = ToolDefinitions.allTools.map { $0.name }
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "Duplicate tool names found")
    }

    // MARK: - toolAccessLevel

    func testToolAccessLevelCoversAllTools() {
        let accessLevels = ToolDefinitions.toolAccessLevel
        for tool in ToolDefinitions.allTools {
            XCTAssertNotNil(accessLevels[tool.name], "Tool \(tool.name) missing from toolAccessLevel mapping")
        }
    }

    func testReadToolsAreClassifiedAsRead() {
        let readTools = ["list_reminder_lists", "list_reminders", "search_reminders",
                         "list_calendars", "list_events", "check_availability", "search_events",
                         "find_conflicts", "find_gaps", "get_calendar_stats",
                         "search_contacts", "get_contact", "list_contact_groups", "get_contacts_in_group",
                         "find_incomplete_contacts",
                         "list_mailboxes", "list_recent_mail", "search_mail", "read_mail",
                         "find_unanswered_mail", "find_threads_awaiting_reply", "list_senders_by_frequency",
                         "list_conversations", "read_conversation", "search_messages",
                         "list_note_folders", "list_notes", "read_note", "search_notes",
                         "find_stale_notes",
                         "list_open_tabs", "list_reading_list", "search_bookmarks", "search_history",
                         "list_bookmark_folders", "find_duplicate_tabs", "get_tab_content",
                         "spotlight_search", "spotlight_search_content", "get_file_metadata", "list_finder_tags", "get_tagged_files",
                         "list_shortcuts", "get_shortcut_details",
                         "meeting_context", "contact_360"]
        for tool in readTools {
            XCTAssertEqual(ToolDefinitions.toolAccessLevel[tool], .read, "Tool \(tool) should be classified as read")
        }
    }

    // MARK: - Annotations

    func testAllToolsHaveAnnotations() {
        for tool in ToolDefinitions.allTools {
            XCTAssertNotNil(tool.annotations, "Tool \(tool.name) should have annotations")
        }
    }

    func testReadToolAnnotationsAreReadOnly() {
        let readTools = ToolDefinitions.allTools.filter {
            ToolDefinitions.toolAccessLevel[$0.name] == .read
        }
        for tool in readTools {
            XCTAssertEqual(tool.annotations?.readOnlyHint, true, "Read tool \(tool.name) should have readOnlyHint=true")
            XCTAssertEqual(tool.annotations?.destructiveHint, false, "Read tool \(tool.name) should have destructiveHint=false")
        }
    }

    func testWriteToolAnnotationsAreNotReadOnly() {
        let writeTools = ToolDefinitions.allTools.filter {
            ToolDefinitions.toolAccessLevel[$0.name] == .write
        }
        for tool in writeTools {
            XCTAssertEqual(tool.annotations?.readOnlyHint, false, "Write tool \(tool.name) should have readOnlyHint=false")
        }
    }

    func testDestructiveToolAnnotations() {
        let destructiveNames = ToolDefinitions.destructiveTools
        for tool in ToolDefinitions.allTools where destructiveNames.contains(tool.name) {
            XCTAssertEqual(tool.annotations?.destructiveHint, true, "Tool \(tool.name) should have destructiveHint=true")
            XCTAssertEqual(tool.annotations?.readOnlyHint, false, "Destructive tool \(tool.name) should not be readOnly")
        }
    }

    func testNonDestructiveWriteToolAnnotations() {
        let nonDestructiveWriteTools = ToolDefinitions.allTools.filter {
            ToolDefinitions.toolAccessLevel[$0.name] == .write && !ToolDefinitions.destructiveTools.contains($0.name)
        }
        for tool in nonDestructiveWriteTools {
            XCTAssertEqual(tool.annotations?.destructiveHint, false, "Non-destructive write tool \(tool.name) should have destructiveHint=false")
        }
    }

    func testAnnotationsEncodeToJSON() throws {
        let tool = ToolDefinitions.allTools.first { $0.name == "list_reminder_lists" }!
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(tool)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let annotations = json["annotations"] as! [String: Any]
        XCTAssertEqual(annotations["readOnlyHint"] as? Bool, true)
        XCTAssertEqual(annotations["destructiveHint"] as? Bool, false)
    }

    func testWriteToolsAreClassifiedAsWrite() {
        let writeTools = ["create_reminder", "update_reminder", "complete_reminder",
                          "move_reminder", "bulk_move_reminders",
                          "create_event", "update_event", "delete_event",
                          "bulk_decline_events",
                          "create_contact", "update_contact",
                          "create_draft", "send_draft", "move_message", "flag_message",
                          "bulk_archive_messages",
                          "send_message",
                          "create_note", "update_note", "delete_note",
                          "append_to_note",
                          "close_tab",
                          "add_to_reading_list", "add_bookmark", "delete_bookmark",
                          "create_bookmark_folder", "close_tabs_matching",
                          "new_tab", "reload_tab",
                          "set_finder_tags",
                          "run_shortcut"]
        for tool in writeTools {
            XCTAssertEqual(ToolDefinitions.toolAccessLevel[tool], .write, "Tool \(tool) should be classified as write")
        }
    }
}
