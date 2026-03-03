import Foundation

/// Protocol for interacting with the macOS Contacts app via AppleScript/Contacts framework.
protocol ContactsProviding {
    func searchContacts(query: String) async throws -> [[String: Any]]
    func getContact(id: String) async throws -> [String: Any]
    func createContact(firstName: String, lastName: String?, email: String?, phone: String?, company: String?) async throws -> [String: Any]
    func updateContact(id: String, firstName: String?, lastName: String?, email: String?, phone: String?, company: String?) async throws -> [String: Any]
    func listGroups() async throws -> [[String: Any]]
    func getContactsInGroup(groupName: String) async throws -> [[String: Any]]
    func findIncompleteContacts() async throws -> [[String: Any]]
    func listAllContacts(limit: Int?, offset: Int?) async throws -> [[String: Any]]
    func deleteContact(id: String, confirmation: Bool) async throws -> [String: Any]
    func bulkUpdateContacts(ids: [String], fields: [String: String]) async throws -> [[String: Any]]
    func mergeContacts(sourceId: String, targetId: String, confirmation: Bool) async throws -> [String: Any]
    func createContactGroup(name: String) async throws -> [String: Any]
    func addContactToGroup(contactId: String, groupName: String) async throws -> [String: Any]
}
