import Foundation
@testable import MacOSLocalMCP

final class MockContactsProvider: ContactsProviding {
    var searchContactsCalled = false
    var getContactCalled = false
    var createContactCalled = false
    var updateContactCalled = false
    var listGroupsCalled = false
    var getContactsInGroupCalled = false
    var deleteContactCalled = false
    var findIncompleteContactsCalled = false
    var listAllContactsCalled = false
    var bulkUpdateContactsCalled = false
    var mergeContactsCalled = false
    var createContactGroupCalled = false
    var addContactToGroupCalled = false

    var searchContactsResult: [[String: Any]] = []
    var getContactResult: [String: Any] = [:]
    var createContactResult: [String: Any] = [:]
    var updateContactResult: [String: Any] = [:]
    var listGroupsResult: [[String: Any]] = []
    var getContactsInGroupResult: [[String: Any]] = []
    var deleteContactResult: [String: Any] = [:]
    var findIncompleteContactsResult: [[String: Any]] = []
    var listAllContactsResult: [[String: Any]] = []
    var bulkUpdateContactsResult: [[String: Any]] = []
    var mergeContactsResult: [String: Any] = [:]
    var createContactGroupResult: [String: Any] = [:]
    var addContactToGroupResult: [String: Any] = [:]

    var searchContactsError: Error?
    var getContactError: Error?
    var createContactError: Error?
    var updateContactError: Error?
    var listGroupsError: Error?
    var getContactsInGroupError: Error?
    var deleteContactError: Error?
    var findIncompleteContactsError: Error?
    var listAllContactsError: Error?
    var bulkUpdateContactsError: Error?
    var mergeContactsError: Error?
    var createContactGroupError: Error?
    var addContactToGroupError: Error?

    var lastSearchQuery: String?
    var lastGetContactId: String?
    var lastCreateFirstName: String?
    var lastDeleteContactId: String?
    var lastDeleteContactConfirmation: Bool?
    var lastListAllContactsLimit: Int?
    var lastListAllContactsOffset: Int?
    var lastBulkUpdateIds: [String]?
    var lastBulkUpdateFields: [String: String]?
    var lastMergeSourceId: String?
    var lastMergeTargetId: String?
    var lastMergeConfirmation: Bool?
    var lastCreateGroupName: String?
    var lastAddContactToGroupContactId: String?
    var lastAddContactToGroupGroupName: String?

    func searchContacts(query: String) async throws -> [[String: Any]] {
        searchContactsCalled = true
        lastSearchQuery = query
        if let error = searchContactsError { throw error }
        return searchContactsResult
    }

    func getContact(id: String) async throws -> [String: Any] {
        getContactCalled = true
        lastGetContactId = id
        if let error = getContactError { throw error }
        return getContactResult
    }

    func createContact(firstName: String, lastName: String?, email: String?, phone: String?, company: String?) async throws -> [String: Any] {
        createContactCalled = true
        lastCreateFirstName = firstName
        if let error = createContactError { throw error }
        return createContactResult
    }

    func updateContact(id: String, firstName: String?, lastName: String?, email: String?, phone: String?, company: String?) async throws -> [String: Any] {
        updateContactCalled = true
        if let error = updateContactError { throw error }
        return updateContactResult
    }

    func listGroups() async throws -> [[String: Any]] {
        listGroupsCalled = true
        if let error = listGroupsError { throw error }
        return listGroupsResult
    }

    func getContactsInGroup(groupName: String) async throws -> [[String: Any]] {
        getContactsInGroupCalled = true
        if let error = getContactsInGroupError { throw error }
        return getContactsInGroupResult
    }

    func findIncompleteContacts() async throws -> [[String: Any]] {
        findIncompleteContactsCalled = true
        if let error = findIncompleteContactsError { throw error }
        return findIncompleteContactsResult
    }

    func deleteContact(id: String, confirmation: Bool) async throws -> [String: Any] {
        deleteContactCalled = true
        lastDeleteContactId = id
        lastDeleteContactConfirmation = confirmation
        if let error = deleteContactError { throw error }
        return deleteContactResult
    }

    func listAllContacts(limit: Int?, offset: Int?) async throws -> [[String: Any]] {
        listAllContactsCalled = true
        lastListAllContactsLimit = limit
        lastListAllContactsOffset = offset
        if let error = listAllContactsError { throw error }
        return listAllContactsResult
    }

    func bulkUpdateContacts(ids: [String], fields: [String: String]) async throws -> [[String: Any]] {
        bulkUpdateContactsCalled = true
        lastBulkUpdateIds = ids
        lastBulkUpdateFields = fields
        if let error = bulkUpdateContactsError { throw error }
        return bulkUpdateContactsResult
    }

    func mergeContacts(sourceId: String, targetId: String, confirmation: Bool) async throws -> [String: Any] {
        mergeContactsCalled = true
        lastMergeSourceId = sourceId
        lastMergeTargetId = targetId
        lastMergeConfirmation = confirmation
        if let error = mergeContactsError { throw error }
        return mergeContactsResult
    }

    func createContactGroup(name: String) async throws -> [String: Any] {
        createContactGroupCalled = true
        lastCreateGroupName = name
        if let error = createContactGroupError { throw error }
        return createContactGroupResult
    }

    func addContactToGroup(contactId: String, groupName: String) async throws -> [String: Any] {
        addContactToGroupCalled = true
        lastAddContactToGroupContactId = contactId
        lastAddContactToGroupGroupName = groupName
        if let error = addContactToGroupError { throw error }
        return addContactToGroupResult
    }
}
