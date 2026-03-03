import Foundation
import Contacts
import AddressBook

/// Concrete implementation of ContactsProviding using the macOS Contacts framework.
/// Handles permission requests gracefully and maps CNContact objects to plain dictionaries.
final class ContactsBridge: ContactsProviding {

    private let store = CNContactStore()

    // MARK: - ContactsProviding

    func searchContacts(query: String) async throws -> [[String: Any]] {
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        return contacts.map { contact(from: $0) }
    }

    func getContact(id: String) async throws -> [String: Any] {
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
        return self.contact(from: contact)
    }

    func createContact(
        firstName: String,
        lastName: String?,
        email: String?,
        phone: String?,
        company: String?
    ) async throws -> [String: Any] {
        try await requestAccess()

        let mutable = CNMutableContact()
        mutable.givenName = firstName
        if let lastName = lastName { mutable.familyName = lastName }
        if let email = email {
            mutable.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }
        if let phone = phone {
            mutable.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        if let company = company { mutable.organizationName = company }

        let request = CNSaveRequest()
        request.add(mutable, toContainerWithIdentifier: nil)
        try store.execute(request)

        return contact(from: mutable)
    }

    func updateContact(
        id: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        phone: String?,
        company: String?
    ) async throws -> [String: Any] {
        try await requestAccess()

        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let existing = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
        guard let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactsBridgeError.mutableCopyFailed
        }

        if let firstName = firstName { mutable.givenName = firstName }
        if let lastName = lastName { mutable.familyName = lastName }
        if let email = email {
            mutable.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }
        if let phone = phone {
            mutable.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        if let company = company { mutable.organizationName = company }

        let request = CNSaveRequest()
        request.update(mutable)
        try store.execute(request)

        return contact(from: mutable)
    }

    func listGroups() async throws -> [[String: Any]] {
        try await requestAccess()
        let groups = try store.groups(matching: nil)
        return groups.map { group(from: $0) }
    }

    func getContactsInGroup(groupName: String) async throws -> [[String: Any]] {
        try await requestAccess()

        // Find the group by name
        let allGroups = try store.groups(matching: nil)
        guard let targetGroup = allGroups.first(where: { $0.name == groupName }) else {
            throw ContactsBridgeError.groupNotFound(groupName)
        }

        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: targetGroup.identifier)
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        return contacts.map { contact(from: $0) }
    }

    func findIncompleteContacts() async throws -> [[String: Any]] {
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let predicate = CNContact.predicateForContacts(matchingName: "")
        // Fetch all contacts using a broad fetch request
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        var incompleteContacts: [[String: Any]] = []
        try store.enumerateContacts(with: fetchRequest) { cnContact, _ in
            let hasEmail = !cnContact.emailAddresses.isEmpty
            let hasPhone = !cnContact.phoneNumbers.isEmpty
            let hasCompany = !cnContact.organizationName.isEmpty
            if !hasEmail || !hasPhone || !hasCompany {
                incompleteContacts.append(self.contact(from: cnContact))
            }
        }
        _ = predicate // suppress unused warning
        return incompleteContacts
    }

    func deleteContact(id: String, confirmation: Bool) async throws -> [String: Any] {
        guard confirmation else {
            return ["id": id, "deleted": false, "error": "confirmation required"]
        }
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        let existing = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
        guard let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactsBridgeError.mutableCopyFailed
        }
        let request = CNSaveRequest()
        request.delete(mutable)
        try store.execute(request)
        return ["id": id, "deleted": true]
    }

    func bulkUpdateContacts(ids: [String], fields: [String: String]) async throws -> [[String: Any]] {
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        var results: [[String: Any]] = []
        for id in ids {
            do {
                let existing = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
                guard let mutable = existing.mutableCopy() as? CNMutableContact else {
                    results.append(["id": id, "updated": false, "error": "mutable copy failed"])
                    continue
                }
                if let firstName = fields["first_name"] { mutable.givenName = firstName }
                if let lastName = fields["last_name"] { mutable.familyName = lastName }
                if let company = fields["company"] { mutable.organizationName = company }
                if let email = fields["email"] {
                    mutable.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
                }
                if let phone = fields["phone"] {
                    mutable.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
                }
                let request = CNSaveRequest()
                request.update(mutable)
                try store.execute(request)
                results.append(contact(from: mutable).merging(["updated": true]) { _, new in new })
            } catch {
                results.append(["id": id, "updated": false, "error": error.localizedDescription])
            }
        }
        return results
    }

    func listAllContacts(limit: Int?, offset: Int?) async throws -> [[String: Any]] {
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        fetchRequest.sortOrder = .givenName
        var allContacts: [[String: Any]] = []
        try store.enumerateContacts(with: fetchRequest) { cnContact, _ in
            allContacts.append(self.contact(from: cnContact))
        }
        let start = offset ?? 0
        let end: Int
        if let limit = limit {
            end = min(start + limit, allContacts.count)
        } else {
            end = allContacts.count
        }
        guard start < allContacts.count else { return [] }
        return Array(allContacts[start..<end])
    }

    func mergeContacts(sourceId: String, targetId: String, confirmation: Bool) async throws -> [String: Any] {
        guard confirmation else {
            return ["merged": false, "error": "confirmation required"]
        }
        try await requestAccess()
        let keysToFetch: [CNKeyDescriptor] = contactKeys()
        let source = try store.unifiedContact(withIdentifier: sourceId, keysToFetch: keysToFetch)
        let target = try store.unifiedContact(withIdentifier: targetId, keysToFetch: keysToFetch)
        guard let mutableTarget = target.mutableCopy() as? CNMutableContact else {
            throw ContactsBridgeError.mutableCopyFailed
        }

        // Fill in blank fields on target from source
        if mutableTarget.givenName.isEmpty && !source.givenName.isEmpty {
            mutableTarget.givenName = source.givenName
        }
        if mutableTarget.familyName.isEmpty && !source.familyName.isEmpty {
            mutableTarget.familyName = source.familyName
        }
        if mutableTarget.organizationName.isEmpty && !source.organizationName.isEmpty {
            mutableTarget.organizationName = source.organizationName
        }

        // Append emails and phones from source that don't already exist on target
        let existingEmails = Set(mutableTarget.emailAddresses.map { $0.value as String })
        for email in source.emailAddresses {
            if !existingEmails.contains(email.value as String) {
                mutableTarget.emailAddresses.append(email)
            }
        }
        let existingPhones = Set(mutableTarget.phoneNumbers.map { $0.value.stringValue })
        for phone in source.phoneNumbers {
            if !existingPhones.contains(phone.value.stringValue) {
                mutableTarget.phoneNumbers.append(phone)
            }
        }

        // Save updated target and delete source
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableTarget)
        try store.execute(saveRequest)

        // Delete source contact
        let sourceForDelete = try store.unifiedContact(withIdentifier: sourceId, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        guard let mutableSource = sourceForDelete.mutableCopy() as? CNMutableContact else {
            throw ContactsBridgeError.mutableCopyFailed
        }
        let deleteRequest = CNSaveRequest()
        deleteRequest.delete(mutableSource)
        try store.execute(deleteRequest)

        return contact(from: mutableTarget).merging(["merged": true, "deletedSourceId": sourceId]) { _, new in new }
    }

    func createContactGroup(name: String) async throws -> [String: Any] {
        try await requestAccess()
        let mutableGroup = CNMutableGroup()
        mutableGroup.name = name
        let request = CNSaveRequest()
        request.add(mutableGroup, toContainerWithIdentifier: nil)
        try store.execute(request)
        return group(from: mutableGroup)
    }

    func addContactToGroup(contactId: String, groupName: String) async throws -> [String: Any] {
        try await requestAccess()
        let allGroups = try store.groups(matching: nil)
        guard let targetGroup = allGroups.first(where: { $0.name == groupName }) else {
            throw ContactsBridgeError.groupNotFound(groupName)
        }
        let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor, CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor]
        let cnContact = try store.unifiedContact(withIdentifier: contactId, keysToFetch: keysToFetch)
        let request = CNSaveRequest()
        request.addMember(cnContact, to: targetGroup)
        try store.execute(request)
        return ["contactId": contactId, "groupName": groupName, "added": true]
    }

    // MARK: - Private Helpers

    /// Request Contacts access, throwing an error if denied.
    private func requestAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                throw ContactsBridgeError.accessDenied
            }
        case .denied, .restricted:
            throw ContactsBridgeError.accessDenied
        @unknown default:
            throw ContactsBridgeError.accessDenied
        }
    }

    /// Keys needed to fetch all relevant contact fields.
    /// Note: CNContactNoteKey is excluded because macOS 15+ throws
    /// CNPropertyNotFetchedException for notes without extended access.
    private func contactKeys() -> [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactMiddleNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor
        ]
    }

    /// Convert a CNContact (or CNMutableContact) into a plain [String: Any] dictionary.
    private func contact(from cnContact: CNContact) -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["id"] = cnContact.identifier
        dict["firstName"] = cnContact.givenName
        dict["middleName"] = cnContact.middleName
        dict["lastName"] = cnContact.familyName
        dict["company"] = cnContact.organizationName

        // Email addresses
        let emails = cnContact.emailAddresses.map { entry -> [String: String] in
            [
                "label": CNLabeledValue<NSString>.localizedString(forLabel: entry.label ?? ""),
                "value": entry.value as String
            ]
        }
        dict["emails"] = emails

        // Phone numbers
        let phones = cnContact.phoneNumbers.map { entry -> [String: String] in
            [
                "label": CNLabeledValue<NSString>.localizedString(forLabel: entry.label ?? ""),
                "value": entry.value.stringValue
            ]
        }
        dict["phones"] = phones

        // Birthday
        if let birthday = cnContact.birthday {
            var components: [String: Int] = [:]
            if let year = birthday.year { components["year"] = year }
            if let month = birthday.month { components["month"] = month }
            if let day = birthday.day { components["day"] = day }
            dict["birthday"] = components
        }

        // Creation/modification dates via legacy AddressBook
        if let ab = ABAddressBook.shared(),
           let abPerson = ab.record(forUniqueId: cnContact.identifier) as? ABPerson {
            let formatter = ISO8601DateFormatter()
            if let created = abPerson.value(forProperty: kABCreationDateProperty as String) as? Date {
                dict["createdAt"] = formatter.string(from: created)
            }
            if let modified = abPerson.value(forProperty: kABModificationDateProperty as String) as? Date {
                dict["modifiedAt"] = formatter.string(from: modified)
            }
        }

        return dict
    }

    /// Convert a CNGroup into a plain [String: Any] dictionary.
    private func group(from cnGroup: CNGroup) -> [String: Any] {
        ["id": cnGroup.identifier, "name": cnGroup.name]
    }
}

// MARK: - Errors

enum ContactsBridgeError: LocalizedError {
    case accessDenied
    case groupNotFound(String)
    case mutableCopyFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Contacts access denied. Please grant access in System Settings > Privacy & Security > Contacts."
        case .groupNotFound(let name):
            return "Contact group '\(name)' not found."
        case .mutableCopyFailed:
            return "Failed to create mutable copy of contact."
        }
    }
}
