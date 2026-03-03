import Foundation

/// Per-module access control for read and write operations.
/// Decodes from either a boolean (backward compat) or {"read": true, "write": false}.
public struct AppModuleAccess: Codable, Equatable {
    public var read: Bool
    public var write: Bool

    public static let allEnabled = AppModuleAccess(read: true, write: true)
    public static let allDisabled = AppModuleAccess(read: false, write: false)
    public static let readOnly = AppModuleAccess(read: true, write: false)

    public init(read: Bool, write: Bool) {
        self.read = read
        self.write = write
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            read = try container.decode(Bool.self, forKey: .read)
            write = try container.decode(Bool.self, forKey: .write)
        } else {
            let container = try decoder.singleValueContainer()
            let enabled = try container.decode(Bool.self)
            read = enabled
            write = enabled
        }
    }

    private enum CodingKeys: String, CodingKey {
        case read, write
    }
}

/// The full application configuration, mirroring config.json written by the MCP server.
public struct AppConfig: Codable, Equatable {

    /// Logging verbosity: "normal", "verbose", "debug".
    public var logLevel: String

    /// Maximum size of the activity log in megabytes.
    public var logMaxSizeMB: Int

    /// Per-module read/write access. Keys match ModuleConfig.allModuleNames.
    public var enabledModules: [String: AppModuleAccess]

    /// Whether each named tool requires user confirmation before execution.
    public var confirmationRequired: [String: Bool]

    public init(
        logLevel: String,
        logMaxSizeMB: Int,
        enabledModules: [String: AppModuleAccess],
        confirmationRequired: [String: Bool]
    ) {
        self.logLevel = logLevel
        self.logMaxSizeMB = logMaxSizeMB
        self.enabledModules = enabledModules
        self.confirmationRequired = confirmationRequired
    }

    /// Default configuration matching the server's defaults.
    public static let defaults = AppConfig(
        logLevel: "normal",
        logMaxSizeMB: 10,
        enabledModules: [
            "reminders":  .allEnabled,
            "calendar":   .allEnabled,
            "contacts":   .allEnabled,
            "mail":       .allEnabled,
            "messages":   .allEnabled,
            "notes":      .allEnabled,
            "safari":     .allEnabled,
            "finder":     .allEnabled,
            "shortcuts":  .allEnabled,
            "system":     .allEnabled,
        ],
        confirmationRequired: [
            "send_message":  true,
            "send_draft":    true,
            "delete_event":  true,
            "delete_note":   true,
            "close_tab":     true,
            "toggle_dnd":    true,
            "run_shortcut":  true,
            "run_shell":     true,
        ]
    )
}
