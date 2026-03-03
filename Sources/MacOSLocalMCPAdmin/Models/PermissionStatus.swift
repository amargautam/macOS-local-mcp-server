import Foundation

/// The authorization status for a macOS framework or capability.
public enum PermissionStatus: Equatable {
    /// The app has been granted access.
    case authorized
    /// The user explicitly denied access.
    case denied
    /// The system has not yet asked the user for this permission.
    case notDetermined
    /// Access is restricted by policy (parental controls, MDM, etc.).
    case restricted

    /// A human-readable label for display in the UI.
    public var label: String {
        switch self {
        case .authorized:    return "Authorized"
        case .denied:        return "Denied"
        case .notDetermined: return "Not Determined"
        case .restricted:    return "Restricted"
        }
    }

    /// Whether the app can currently use this capability.
    public var isAllowed: Bool {
        self == .authorized
    }
}

/// The permission status for a named module.
public struct ModulePermission: Identifiable, Equatable {
    public var id: String { moduleName }

    /// The internal module identifier (e.g., "reminders", "calendar").
    public let moduleName: String

    /// The human-readable display name (e.g., "Reminders", "Calendar").
    public let displayName: String

    /// The current authorization status.
    public let status: PermissionStatus

    /// An optional short note explaining why access might be restricted.
    public let note: String?

    public init(
        moduleName: String,
        displayName: String,
        status: PermissionStatus,
        note: String? = nil
    ) {
        self.moduleName = moduleName
        self.displayName = displayName
        self.status = status
        self.note = note
    }
}
