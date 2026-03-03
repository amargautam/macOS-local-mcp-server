import Foundation

/// Configuration for a single MCP module.
public struct ModuleConfig: Codable, Identifiable, Equatable {
    public var id: String { name }

    /// The internal module identifier matching the server's config keys.
    public let name: String

    /// The human-readable display name shown in the UI.
    public let displayName: String

    /// Whether read tools are enabled for this module.
    public var readEnabled: Bool

    /// Whether write tools are enabled for this module.
    public var writeEnabled: Bool

    /// Whether either read or write is enabled.
    public var isEnabled: Bool { readEnabled || writeEnabled }

    public init(name: String, displayName: String, readEnabled: Bool, writeEnabled: Bool) {
        self.name = name
        self.displayName = displayName
        self.readEnabled = readEnabled
        self.writeEnabled = writeEnabled
    }
}

extension ModuleConfig {
    /// The canonical list of all supported modules in display order.
    public static let allModuleNames: [(name: String, displayName: String)] = [
        ("reminders",  "Reminders"),
        ("calendar",   "Calendar"),
        ("contacts",   "Contacts"),
        ("mail",       "Mail"),
        ("messages",   "Messages"),
        ("notes",      "Notes"),
        ("safari",     "Safari"),
        ("finder",     "Finder"),
        ("shortcuts",  "Shortcuts"),
        ("system",     "System"),
    ]
}
