import XCTest
@testable import MacOSLocalMCP

final class ContactsToolTests: XCTestCase {

    var provider: MockContactsProvider!
    var tool: ContactsTool!
    var handlers: [String: MCPToolHandler]!

    override func setUp() {
        super.setUp()
        provider = MockContactsProvider()
        tool = ContactsTool(provider: provider)

        // Build a lookup dictionary from the handlers array
        var dict: [String: MCPToolHandler] = [:]
        for handler in tool.createHandlers() {
            dict[handler.toolName] = handler
        }
        handlers = dict
    }

    // MARK: - Handler Registration

    func testCreateHandlersReturnsThirteenHandlers() {
        XCTAssertEqual(tool.createHandlers().count, 13)
    }

    func testAllExpectedToolNamesRegistered() {
        let names = Set(handlers.keys)
        XCTAssertTrue(names.contains("search_contacts"))
        XCTAssertTrue(names.contains("get_contact"))
        XCTAssertTrue(names.contains("create_contact"))
        XCTAssertTrue(names.contains("update_contact"))
        XCTAssertTrue(names.contains("list_contact_groups"))
        XCTAssertTrue(names.contains("get_contacts_in_group"))
        XCTAssertTrue(names.contains("find_incomplete_contacts"))
        XCTAssertTrue(names.contains("delete_contact"))
        XCTAssertTrue(names.contains("list_all_contacts"))
        XCTAssertTrue(names.contains("merge_contacts"))
        XCTAssertTrue(names.contains("bulk_update_contacts"))
        XCTAssertTrue(names.contains("create_contact_group"))
        XCTAssertTrue(names.contains("add_contact_to_group"))
    }

    // MARK: - search_contacts

    func testSearchContactsHappyPath() async throws {
        provider.searchContactsResult = [
            ["id": "1", "firstName": "John", "lastName": "Doe", "email": "john@example.com"],
            ["id": "2", "firstName": "Jane", "lastName": "Doe", "email": "jane@example.com"]
        ]

        let result = try await handlers["search_contacts"]!.handle(arguments: [
            "query": .string("Doe")
        ])

        XCTAssertTrue(provider.searchContactsCalled)
        XCTAssertEqual(provider.lastSearchQuery, "Doe")
        XCTAssertFalse(result.isError ?? false)
        XCTAssertNotNil(result.content.first?.text)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("John"))
        XCTAssertTrue(text.contains("Jane"))
    }

    func testSearchContactsMissingQueryReturnsError() async throws {
        let result = try await handlers["search_contacts"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("query"))
    }

    func testSearchContactsEmptyResultsReturnsEmptyArray() async throws {
        provider.searchContactsResult = []

        let result = try await handlers["search_contacts"]!.handle(arguments: [
            "query": .string("nobody")
        ])

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertEqual(text, "[]")
    }

    func testSearchContactsProviderErrorReturnsError() async throws {
        provider.searchContactsError = NSError(
            domain: "ContactsError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Contacts access denied"]
        )

        let result = try await handlers["search_contacts"]!.handle(arguments: [
            "query": .string("test")
        ])

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Contacts access denied"))
    }

    // MARK: - get_contact

    func testGetContactHappyPath() async throws {
        provider.getContactResult = [
            "id": "abc-123",
            "firstName": "Alice",
            "lastName": "Smith",
            "email": "alice@example.com",
            "phone": "+1234567890",
            "company": "Acme Corp"
        ]

        let result = try await handlers["get_contact"]!.handle(arguments: [
            "id": .string("abc-123")
        ])

        XCTAssertTrue(provider.getContactCalled)
        XCTAssertEqual(provider.lastGetContactId, "abc-123")
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Alice"))
        XCTAssertTrue(text.contains("abc-123"))
    }

    func testGetContactMissingIdReturnsError() async throws {
        let result = try await handlers["get_contact"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("id"))
    }

    func testGetContactProviderErrorReturnsError() async throws {
        provider.getContactError = NSError(
            domain: "ContactsError", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Contact not found"]
        )

        let result = try await handlers["get_contact"]!.handle(arguments: [
            "id": .string("nonexistent")
        ])

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Contact not found"))
    }

    func testGetContactWithWrongArgumentTypeReturnsError() async throws {
        let result = try await handlers["get_contact"]!.handle(arguments: [
            "id": .int(42)
        ])

        XCTAssertEqual(result.isError, true)
    }

    // MARK: - create_contact

    func testCreateContactHappyPath() async throws {
        provider.createContactResult = [
            "id": "new-456",
            "firstName": "Bob",
            "lastName": "Jones",
            "email": "bob@example.com",
            "phone": "+9876543210",
            "company": "TechCo"
        ]

        let result = try await handlers["create_contact"]!.handle(arguments: [
            "first_name": .string("Bob"),
            "last_name": .string("Jones"),
            "email": .string("bob@example.com"),
            "phone": .string("+9876543210"),
            "company": .string("TechCo")
        ])

        XCTAssertTrue(provider.createContactCalled)
        XCTAssertEqual(provider.lastCreateFirstName, "Bob")
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Bob"))
        XCTAssertTrue(text.contains("new-456"))
    }

    func testCreateContactMinimalRequiredField() async throws {
        provider.createContactResult = [
            "id": "min-789",
            "firstName": "Min"
        ]

        let result = try await handlers["create_contact"]!.handle(arguments: [
            "first_name": .string("Min")
        ])

        XCTAssertTrue(provider.createContactCalled)
        XCTAssertEqual(provider.lastCreateFirstName, "Min")
        XCTAssertFalse(result.isError ?? false)
    }

    func testCreateContactMissingFirstNameReturnsError() async throws {
        let result = try await handlers["create_contact"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("first_name"))
    }

    func testCreateContactProviderErrorReturnsError() async throws {
        provider.createContactError = NSError(
            domain: "ContactsError", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create contact"]
        )

        let result = try await handlers["create_contact"]!.handle(arguments: [
            "first_name": .string("Error")
        ])

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Failed to create contact"))
    }

    // MARK: - update_contact

    func testUpdateContactHappyPath() async throws {
        provider.updateContactResult = [
            "id": "upd-001",
            "firstName": "Updated",
            "lastName": "Name",
            "email": "updated@example.com"
        ]

        let result = try await handlers["update_contact"]!.handle(arguments: [
            "id": .string("upd-001"),
            "first_name": .string("Updated"),
            "last_name": .string("Name"),
            "email": .string("updated@example.com")
        ])

        XCTAssertTrue(provider.updateContactCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Updated"))
    }

    func testUpdateContactOnlyIdRequired() async throws {
        provider.updateContactResult = ["id": "upd-002", "firstName": "Same"]

        let result = try await handlers["update_contact"]!.handle(arguments: [
            "id": .string("upd-002")
        ])

        XCTAssertTrue(provider.updateContactCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testUpdateContactMissingIdReturnsError() async throws {
        let result = try await handlers["update_contact"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("id"))
    }

    func testUpdateContactProviderErrorReturnsError() async throws {
        provider.updateContactError = NSError(
            domain: "ContactsError", code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Update failed"]
        )

        let result = try await handlers["update_contact"]!.handle(arguments: [
            "id": .string("err-id")
        ])

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Update failed"))
    }

    // MARK: - list_contact_groups

    func testListContactGroupsHappyPath() async throws {
        provider.listGroupsResult = [
            ["id": "grp-1", "name": "Family"],
            ["id": "grp-2", "name": "Work"]
        ]

        let result = try await handlers["list_contact_groups"]!.handle(arguments: nil)

        XCTAssertTrue(provider.listGroupsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Family"))
        XCTAssertTrue(text.contains("Work"))
    }

    func testListContactGroupsEmptyReturnsEmptyArray() async throws {
        provider.listGroupsResult = []

        let result = try await handlers["list_contact_groups"]!.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertEqual(text, "[]")
    }

    func testListContactGroupsProviderErrorReturnsError() async throws {
        provider.listGroupsError = NSError(
            domain: "ContactsError", code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Groups unavailable"]
        )

        let result = try await handlers["list_contact_groups"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Groups unavailable"))
    }

    // MARK: - get_contacts_in_group

    func testGetContactsInGroupHappyPath() async throws {
        provider.getContactsInGroupResult = [
            ["id": "c1", "firstName": "Carol", "lastName": "White"],
            ["id": "c2", "firstName": "Dave", "lastName": "Black"]
        ]

        let result = try await handlers["get_contacts_in_group"]!.handle(arguments: [
            "group_name": .string("Family")
        ])

        XCTAssertTrue(provider.getContactsInGroupCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Carol"))
        XCTAssertTrue(text.contains("Dave"))
    }

    func testGetContactsInGroupMissingGroupNameReturnsError() async throws {
        let result = try await handlers["get_contacts_in_group"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("group_name"))
    }

    func testGetContactsInGroupProviderErrorReturnsError() async throws {
        provider.getContactsInGroupError = NSError(
            domain: "ContactsError", code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Group not found"]
        )

        let result = try await handlers["get_contacts_in_group"]!.handle(arguments: [
            "group_name": .string("Nonexistent")
        ])

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Group not found"))
    }

    func testGetContactsInGroupEmptyResultReturnsEmptyArray() async throws {
        provider.getContactsInGroupResult = []

        let result = try await handlers["get_contacts_in_group"]!.handle(arguments: [
            "group_name": .string("Empty Group")
        ])

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertEqual(text, "[]")
    }

    // MARK: - find_incomplete_contacts

    func testFindIncompleteContactsHappyPath() async throws {
        provider.findIncompleteContactsResult = [
            ["id": "c1", "firstName": "John", "lastName": "NoEmail"],
            ["id": "c2", "firstName": "Jane", "lastName": "NoPhone"]
        ]

        let result = try await handlers["find_incomplete_contacts"]!.handle(arguments: nil)

        XCTAssertTrue(provider.findIncompleteContactsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("John"))
        XCTAssertTrue(text.contains("Jane"))
    }

    func testFindIncompleteContactsEmptyResult() async throws {
        provider.findIncompleteContactsResult = []

        let result = try await handlers["find_incomplete_contacts"]!.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertEqual(text, "[]")
    }

    func testFindIncompleteContactsProviderError() async throws {
        provider.findIncompleteContactsError = NSError(
            domain: "ContactsError", code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Contacts unavailable"]
        )

        let result = try await handlers["find_incomplete_contacts"]!.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Contacts unavailable"))
    }

    func testFindIncompleteContactsIgnoresArguments() async throws {
        provider.findIncompleteContactsResult = [["id": "c1", "firstName": "Test"]]

        // Tool takes no params, passing args should still work fine
        let result = try await handlers["find_incomplete_contacts"]!.handle(arguments: [
            "unexpected_param": .string("value")
        ])

        XCTAssertTrue(provider.findIncompleteContactsCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    // MARK: - delete_contact

    func testDeleteContactHappyPath() async throws {
        provider.deleteContactResult = ["id": "del-1", "deleted": true]
        let handler = try XCTUnwrap(handlers["delete_contact"])
        let result = try await handler.handle(arguments: [
            "id": .string("del-1"),
            "confirmation": .bool(true)
        ])
        XCTAssertTrue(provider.deleteContactCalled)
        XCTAssertEqual(provider.lastDeleteContactId, "del-1")
        XCTAssertEqual(provider.lastDeleteContactConfirmation, true)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("del-1"))
        XCTAssertTrue(text.contains("true"))
    }

    func testDeleteContactWithoutConfirmation() async throws {
        provider.deleteContactResult = ["id": "del-2", "deleted": false, "error": "confirmation required"]
        let handler = try XCTUnwrap(handlers["delete_contact"])
        let result = try await handler.handle(arguments: [
            "id": .string("del-2")
        ])
        XCTAssertTrue(provider.deleteContactCalled)
        XCTAssertEqual(provider.lastDeleteContactConfirmation, false)
        XCTAssertFalse(result.isError ?? false)
    }

    func testDeleteContactMissingIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["delete_contact"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("id"))
    }

    func testDeleteContactProviderErrorReturnsError() async throws {
        provider.deleteContactError = NSError(
            domain: "ContactsError", code: 10,
            userInfo: [NSLocalizedDescriptionKey: "Delete failed"]
        )
        let handler = try XCTUnwrap(handlers["delete_contact"])
        let result = try await handler.handle(arguments: [
            "id": .string("err-id"),
            "confirmation": .bool(true)
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Delete failed"))
    }

    // MARK: - bulk_update_contacts

    func testBulkUpdateContactsHappyPath() async throws {
        provider.bulkUpdateContactsResult = [
            ["id": "c1", "firstName": "Alice", "company": "NewCo", "updated": true],
            ["id": "c2", "firstName": "Bob", "company": "NewCo", "updated": true]
        ]
        let handler = try XCTUnwrap(handlers["bulk_update_contacts"])
        let result = try await handler.handle(arguments: [
            "ids": .array([.string("c1"), .string("c2")]),
            "fields": .object(["company": .string("NewCo")])
        ])
        XCTAssertTrue(provider.bulkUpdateContactsCalled)
        XCTAssertEqual(provider.lastBulkUpdateIds, ["c1", "c2"])
        XCTAssertEqual(provider.lastBulkUpdateFields, ["company": "NewCo"])
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("NewCo"))
    }

    func testBulkUpdateContactsMissingIdsReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["bulk_update_contacts"])
        let result = try await handler.handle(arguments: [
            "fields": .object(["company": .string("NewCo")])
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("ids"))
    }

    func testBulkUpdateContactsMissingFieldsReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["bulk_update_contacts"])
        let result = try await handler.handle(arguments: [
            "ids": .array([.string("c1")])
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("fields"))
    }

    func testBulkUpdateContactsProviderErrorReturnsError() async throws {
        provider.bulkUpdateContactsError = NSError(
            domain: "ContactsError", code: 13,
            userInfo: [NSLocalizedDescriptionKey: "Bulk update failed"]
        )
        let handler = try XCTUnwrap(handlers["bulk_update_contacts"])
        let result = try await handler.handle(arguments: [
            "ids": .array([.string("c1")]),
            "fields": .object(["company": .string("NewCo")])
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Bulk update failed"))
    }

    func testBulkUpdateContactsEmptyIdsReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["bulk_update_contacts"])
        let result = try await handler.handle(arguments: [
            "ids": .array([]),
            "fields": .object(["company": .string("NewCo")])
        ])
        XCTAssertEqual(result.isError, true)
    }

    // MARK: - merge_contacts

    func testMergeContactsHappyPath() async throws {
        provider.mergeContactsResult = [
            "id": "target-1", "firstName": "Alice", "merged": true, "deletedSourceId": "source-1"
        ]
        let handler = try XCTUnwrap(handlers["merge_contacts"])
        let result = try await handler.handle(arguments: [
            "source_id": .string("source-1"),
            "target_id": .string("target-1"),
            "confirmation": .bool(true)
        ])
        XCTAssertTrue(provider.mergeContactsCalled)
        XCTAssertEqual(provider.lastMergeSourceId, "source-1")
        XCTAssertEqual(provider.lastMergeTargetId, "target-1")
        XCTAssertEqual(provider.lastMergeConfirmation, true)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("target-1"))
    }

    func testMergeContactsWithoutConfirmation() async throws {
        provider.mergeContactsResult = ["merged": false, "error": "confirmation required"]
        let handler = try XCTUnwrap(handlers["merge_contacts"])
        let result = try await handler.handle(arguments: [
            "source_id": .string("s1"),
            "target_id": .string("t1")
        ])
        XCTAssertTrue(provider.mergeContactsCalled)
        XCTAssertEqual(provider.lastMergeConfirmation, false)
        XCTAssertFalse(result.isError ?? false)
    }

    func testMergeContactsMissingSourceIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["merge_contacts"])
        let result = try await handler.handle(arguments: [
            "target_id": .string("t1"),
            "confirmation": .bool(true)
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("source_id"))
    }

    func testMergeContactsMissingTargetIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["merge_contacts"])
        let result = try await handler.handle(arguments: [
            "source_id": .string("s1"),
            "confirmation": .bool(true)
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("target_id"))
    }

    func testMergeContactsProviderErrorReturnsError() async throws {
        provider.mergeContactsError = NSError(
            domain: "ContactsError", code: 12,
            userInfo: [NSLocalizedDescriptionKey: "Merge failed"]
        )
        let handler = try XCTUnwrap(handlers["merge_contacts"])
        let result = try await handler.handle(arguments: [
            "source_id": .string("s1"),
            "target_id": .string("t1"),
            "confirmation": .bool(true)
        ])
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Merge failed"))
    }

    // MARK: - list_all_contacts

    func testListAllContactsHappyPath() async throws {
        provider.listAllContactsResult = [
            ["id": "1", "firstName": "Alice"],
            ["id": "2", "firstName": "Bob"],
            ["id": "3", "firstName": "Carol"]
        ]
        let handler = try XCTUnwrap(handlers["list_all_contacts"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(provider.listAllContactsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Alice"))
        XCTAssertTrue(text.contains("Bob"))
        XCTAssertTrue(text.contains("Carol"))
    }

    func testListAllContactsWithLimitAndOffset() async throws {
        provider.listAllContactsResult = [["id": "2", "firstName": "Bob"]]
        let handler = try XCTUnwrap(handlers["list_all_contacts"])
        let result = try await handler.handle(arguments: [
            "limit": .int(1),
            "offset": .int(1)
        ])
        XCTAssertTrue(provider.listAllContactsCalled)
        XCTAssertEqual(provider.lastListAllContactsLimit, 1)
        XCTAssertEqual(provider.lastListAllContactsOffset, 1)
        XCTAssertFalse(result.isError ?? false)
    }

    func testListAllContactsEmptyReturnsEmptyArray() async throws {
        provider.listAllContactsResult = []
        let handler = try XCTUnwrap(handlers["list_all_contacts"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertEqual(text, "[]")
    }

    func testListAllContactsProviderErrorReturnsError() async throws {
        provider.listAllContactsError = NSError(
            domain: "ContactsError", code: 11,
            userInfo: [NSLocalizedDescriptionKey: "Contacts unavailable"]
        )
        let handler = try XCTUnwrap(handlers["list_all_contacts"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Contacts unavailable"))
    }

    // MARK: - create_contact_group

    func testCreateContactGroupCallsProvider() async throws {
        provider.createContactGroupResult = ["id": "group-1", "name": "Work Friends"]
        let handler = try XCTUnwrap(handlers["create_contact_group"])
        let result = try await handler.handle(arguments: ["name": .string("Work Friends")])
        XCTAssertTrue(provider.createContactGroupCalled)
        XCTAssertEqual(provider.lastCreateGroupName, "Work Friends")
        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Work Friends"))
    }

    func testCreateContactGroupMissingNameReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["create_contact_group"])
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(result.isError ?? false)
    }

    func testCreateContactGroupProviderErrorReturnsError() async throws {
        provider.createContactGroupError = NSError(
            domain: "ContactsError", code: 12,
            userInfo: [NSLocalizedDescriptionKey: "Group creation failed"]
        )
        let handler = try XCTUnwrap(handlers["create_contact_group"])
        let result = try await handler.handle(arguments: ["name": .string("Test")])
        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Group creation failed"))
    }

    // MARK: - add_contact_to_group

    func testAddContactToGroupCallsProvider() async throws {
        provider.addContactToGroupResult = ["contactId": "c1", "groupName": "Family", "added": true]
        let handler = try XCTUnwrap(handlers["add_contact_to_group"])
        let result = try await handler.handle(arguments: [
            "contact_id": .string("c1"),
            "group_name": .string("Family")
        ])
        XCTAssertTrue(provider.addContactToGroupCalled)
        XCTAssertEqual(provider.lastAddContactToGroupContactId, "c1")
        XCTAssertEqual(provider.lastAddContactToGroupGroupName, "Family")
        XCTAssertFalse(result.isError ?? false)
    }

    func testAddContactToGroupMissingContactIdReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["add_contact_to_group"])
        let result = try await handler.handle(arguments: ["group_name": .string("Family")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testAddContactToGroupMissingGroupNameReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["add_contact_to_group"])
        let result = try await handler.handle(arguments: ["contact_id": .string("c1")])
        XCTAssertTrue(result.isError ?? false)
    }

    func testAddContactToGroupProviderErrorReturnsError() async throws {
        provider.addContactToGroupError = NSError(
            domain: "ContactsError", code: 13,
            userInfo: [NSLocalizedDescriptionKey: "Contact group 'Missing' not found."]
        )
        let handler = try XCTUnwrap(handlers["add_contact_to_group"])
        let result = try await handler.handle(arguments: [
            "contact_id": .string("c1"),
            "group_name": .string("Missing")
        ])
        XCTAssertTrue(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("not found"))
    }
}
