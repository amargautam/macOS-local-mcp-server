import Foundation

/// Tool handlers for Contacts operations.
/// Depends on ContactsProviding via protocol — never on a concrete bridge.
final class ContactsTool {

    private let provider: ContactsProviding

    init(provider: ContactsProviding) {
        self.provider = provider
    }

    /// Build all MCPToolHandlers for the contacts module.
    func createHandlers() -> [MCPToolHandler] {
        [
            makeSearchContacts(),
            makeGetContact(),
            makeCreateContact(),
            makeUpdateContact(),
            makeListContactGroups(),
            makeGetContactsInGroup(),
            makeFindIncompleteContacts(),
            makeDeleteContact(),
            makeBulkUpdateContacts(),
            makeListAllContacts(),
            makeMergeContacts(),
            makeCreateContactGroup(),
            makeAddContactToGroup()
        ]
    }

    // MARK: - Private Helpers

    /// Serialise an array of [String: Any] dictionaries to a compact JSON string.
    private func serialise(_ items: [[String: Any]]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let value = JSONValue.from(arrayOfDictionaries: items)
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Serialise a single [String: Any] dictionary to a compact JSON string.
    private func serialiseObject(_ item: [String: Any]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let value = JSONValue.from(dictionary: item)
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Handler Factories

    private func makeSearchContacts() -> MCPToolHandler {
        ClosureToolHandler(toolName: "search_contacts") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }
            do {
                let results = try await self.provider.searchContacts(query: query)
                let text = try self.serialise(results)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeGetContact() -> MCPToolHandler {
        ClosureToolHandler(toolName: "get_contact") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }
            do {
                let contact = try await self.provider.getContact(id: id)
                let text = try self.serialiseObject(contact)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeCreateContact() -> MCPToolHandler {
        ClosureToolHandler(toolName: "create_contact") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let firstName) = args["first_name"] else {
                return .error("Missing required parameter: first_name")
            }
            let lastName: String? = {
                if case .string(let v) = args["last_name"] { return v }
                return nil
            }()
            let email: String? = {
                if case .string(let v) = args["email"] { return v }
                return nil
            }()
            let phone: String? = {
                if case .string(let v) = args["phone"] { return v }
                return nil
            }()
            let company: String? = {
                if case .string(let v) = args["company"] { return v }
                return nil
            }()
            do {
                let contact = try await self.provider.createContact(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    phone: phone,
                    company: company
                )
                let text = try self.serialiseObject(contact)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeUpdateContact() -> MCPToolHandler {
        ClosureToolHandler(toolName: "update_contact") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }
            let firstName: String? = {
                if case .string(let v) = args["first_name"] { return v }
                return nil
            }()
            let lastName: String? = {
                if case .string(let v) = args["last_name"] { return v }
                return nil
            }()
            let email: String? = {
                if case .string(let v) = args["email"] { return v }
                return nil
            }()
            let phone: String? = {
                if case .string(let v) = args["phone"] { return v }
                return nil
            }()
            let company: String? = {
                if case .string(let v) = args["company"] { return v }
                return nil
            }()
            do {
                let contact = try await self.provider.updateContact(
                    id: id,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    phone: phone,
                    company: company
                )
                let text = try self.serialiseObject(contact)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeListContactGroups() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_contact_groups") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            do {
                let groups = try await self.provider.listGroups()
                let text = try self.serialise(groups)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeGetContactsInGroup() -> MCPToolHandler {
        ClosureToolHandler(toolName: "get_contacts_in_group") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let groupName) = args["group_name"] else {
                return .error("Missing required parameter: group_name")
            }
            do {
                let contacts = try await self.provider.getContactsInGroup(groupName: groupName)
                let text = try self.serialise(contacts)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeFindIncompleteContacts() -> MCPToolHandler {
        ClosureToolHandler(toolName: "find_incomplete_contacts") { [weak self] _ in
            guard let self else { return .error("ContactsTool deallocated") }
            do {
                let contacts = try await self.provider.findIncompleteContacts()
                let text = try self.serialise(contacts)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeDeleteContact() -> MCPToolHandler {
        ClosureToolHandler(toolName: "delete_contact") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let id) = args["id"] else {
                return .error("Missing required parameter: id")
            }
            let confirmation: Bool = {
                if case .bool(let v) = args["confirmation"] { return v }
                return false
            }()
            do {
                let result = try await self.provider.deleteContact(id: id, confirmation: confirmation)
                let text = try self.serialiseObject(result)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeBulkUpdateContacts() -> MCPToolHandler {
        ClosureToolHandler(toolName: "bulk_update_contacts") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .array(let idValues) = args["ids"] else {
                return .error("Missing required parameter: ids (array of strings)")
            }
            let ids = idValues.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
            guard !ids.isEmpty else {
                return .error("ids array must contain at least one contact ID")
            }
            guard case .object(let fieldsDict) = args["fields"] else {
                return .error("Missing required parameter: fields (object with field names and values)")
            }
            var fields: [String: String] = [:]
            for (key, value) in fieldsDict {
                if case .string(let v) = value {
                    fields[key] = v
                }
            }
            guard !fields.isEmpty else {
                return .error("fields must contain at least one field to update")
            }
            do {
                let results = try await self.provider.bulkUpdateContacts(ids: ids, fields: fields)
                let text = try self.serialise(results)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeListAllContacts() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_all_contacts") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            let limit: Int? = {
                if case .int(let v) = arguments?["limit"] { return v }
                return nil
            }()
            let offset: Int? = {
                if case .int(let v) = arguments?["offset"] { return v }
                return nil
            }()
            do {
                let contacts = try await self.provider.listAllContacts(limit: limit, offset: offset)
                let text = try self.serialise(contacts)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeCreateContactGroup() -> MCPToolHandler {
        ClosureToolHandler(toolName: "create_contact_group") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let name) = args["name"] else {
                return .error("Missing required parameter: name")
            }
            do {
                let result = try await self.provider.createContactGroup(name: name)
                let text = try self.serialiseObject(result)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeAddContactToGroup() -> MCPToolHandler {
        ClosureToolHandler(toolName: "add_contact_to_group") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let contactId) = args["contact_id"] else {
                return .error("Missing required parameter: contact_id")
            }
            guard case .string(let groupName) = args["group_name"] else {
                return .error("Missing required parameter: group_name")
            }
            do {
                let result = try await self.provider.addContactToGroup(contactId: contactId, groupName: groupName)
                let text = try self.serialiseObject(result)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeMergeContacts() -> MCPToolHandler {
        ClosureToolHandler(toolName: "merge_contacts") { [weak self] arguments in
            guard let self else { return .error("ContactsTool deallocated") }
            guard let args = arguments,
                  case .string(let sourceId) = args["source_id"] else {
                return .error("Missing required parameter: source_id")
            }
            guard case .string(let targetId) = args["target_id"] else {
                return .error("Missing required parameter: target_id")
            }
            let confirmation: Bool
            if case .bool(let b) = args["confirmation"] {
                confirmation = b
            } else {
                confirmation = false
            }
            do {
                let result = try await self.provider.mergeContacts(
                    sourceId: sourceId,
                    targetId: targetId,
                    confirmation: confirmation
                )
                let text = try self.serialiseObject(result)
                return .text(text)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }
}
