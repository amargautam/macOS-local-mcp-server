import Foundation

/// Manages configuration for the macOS Local MCP server.
/// Reads from `~/.macos-local-mcp/config.json` and provides runtime access to settings.
final class ConfigManager {

    /// The configuration data directory.
    static let configDirectory: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp"
    }()

    /// Path to the config file.
    static let configFilePath: String = {
        return "\(configDirectory)/config.json"
    }()

    /// The current configuration data.
    private(set) var config: ConfigData

    /// Optional file watcher for live reload (stub interface for now).
    private var fileWatcherSource: DispatchSourceFileSystemObject?

    /// Callback invoked when the config file changes.
    var onConfigReload: ((ConfigData) -> Void)?

    /// Initialize with a specific config. Used for testing.
    init(config: ConfigData) {
        self.config = config
    }

    /// Initialize by loading config from the default file path.
    convenience init() {
        let data = ConfigManager.loadConfigData(from: ConfigManager.configFilePath)
        self.init(config: data)
    }

    /// Initialize by loading config from a specific file path.
    convenience init(configFilePath: String) {
        let data = ConfigManager.loadConfigData(from: configFilePath)
        self.init(config: data)
    }

    // MARK: - Public API

    /// Check whether a specific module has any access enabled (read or write).
    func isModuleEnabled(module: String) -> Bool {
        guard let access = config.enabledModules[module] else { return false }
        return access.read || access.write
    }

    /// Check whether a tool's access level (read or write) is enabled for its module.
    func isToolAccessEnabled(module: String, accessLevel: ToolAccessLevel) -> Bool {
        guard let access = config.enabledModules[module] else { return false }
        switch accessLevel {
        case .read: return access.read
        case .write: return access.write
        }
    }

    /// Check whether a specific tool requires user confirmation before execution.
    func isConfirmationRequired(tool: String) -> Bool {
        return config.confirmationRequired[tool] ?? false
    }

    /// The configured log level.
    var logLevel: String {
        return config.logLevel
    }

    /// The configured maximum log file size in MB.
    var logMaxSizeMB: Int {
        return config.logMaxSizeMB
    }

    /// Reload the configuration from disk.
    func reload() {
        config = ConfigManager.loadConfigData(from: ConfigManager.configFilePath)
        onConfigReload?(config)
    }

    /// Reload configuration from a specific path.
    func reload(from path: String) {
        config = ConfigManager.loadConfigData(from: path)
        onConfigReload?(config)
    }

    // MARK: - File Watching (Stub Interface)

    /// Start watching the config file for changes.
    /// Currently a stub -- the interface is defined but FSEvents are not wired yet.
    func startWatching() {
        // Stub: In a full implementation, this would use DispatchSource or FSEvents
        // to watch `~/.macos-local-mcp/config.json` and call reload() on changes.
    }

    /// Stop watching the config file.
    func stopWatching() {
        fileWatcherSource?.cancel()
        fileWatcherSource = nil
    }

    // MARK: - Private

    /// Load and parse config data from a file path, returning defaults if the file is missing or invalid.
    static func loadConfigData(from path: String) -> ConfigData {
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else {
            return ConfigData.defaults
        }

        let decoder = JSONDecoder()
        do {
            let configData = try decoder.decode(ConfigData.self, from: data)
            return configData
        } catch {
            // If parsing fails, return defaults
            return ConfigData.defaults
        }
    }

    /// Ensure the config directory exists with restrictive permissions (owner-only).
    static func ensureConfigDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDirectory) {
            try fm.createDirectory(
                atPath: configDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
    }

    /// Write the default config to disk if no config file exists.
    /// Files are created with 600 permissions (owner read/write only).
    static func writeDefaultConfigIfNeeded() throws {
        try ensureConfigDirectory()
        let fm = FileManager.default
        if !fm.fileExists(atPath: configFilePath) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(ConfigData.defaults)
            fm.createFile(atPath: configFilePath, contents: data, attributes: [.posixPermissions: 0o600])
        }
    }
}

// MARK: - ModuleAccess

/// Per-module access control for read and write operations.
/// Decodes from either a boolean (backward compat) or {"read": true, "write": false}.
struct ModuleAccess: Codable, Equatable {
    var read: Bool
    var write: Bool

    static let allEnabled = ModuleAccess(read: true, write: true)
    static let allDisabled = ModuleAccess(read: false, write: false)
    static let readOnly = ModuleAccess(read: true, write: false)

    init(read: Bool, write: Bool) {
        self.read = read
        self.write = write
    }

    init(from decoder: Decoder) throws {
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

// MARK: - ConfigData

/// The configuration data structure, matching the JSON schema.
struct ConfigData: Codable, Equatable {
    let logLevel: String
    let logMaxSizeMB: Int
    let enabledModules: [String: ModuleAccess]
    let confirmationRequired: [String: Bool]

    init(logLevel: String, logMaxSizeMB: Int, enabledModules: [String: ModuleAccess], confirmationRequired: [String: Bool]) {
        self.logLevel = logLevel
        self.logMaxSizeMB = logMaxSizeMB
        self.enabledModules = enabledModules
        self.confirmationRequired = confirmationRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel) ?? ConfigData.defaults.logLevel
        logMaxSizeMB = try container.decodeIfPresent(Int.self, forKey: .logMaxSizeMB) ?? ConfigData.defaults.logMaxSizeMB
        enabledModules = try container.decodeIfPresent([String: ModuleAccess].self, forKey: .enabledModules) ?? ConfigData.defaults.enabledModules
        confirmationRequired = try container.decodeIfPresent([String: Bool].self, forKey: .confirmationRequired) ?? ConfigData.defaults.confirmationRequired
    }

    private enum CodingKeys: String, CodingKey {
        case logLevel, logMaxSizeMB, enabledModules, confirmationRequired
    }

    /// Default configuration values.
    /// Defaults to read-only for all modules. Users must explicitly enable write access.
    static let defaults = ConfigData(
        logLevel: "normal",
        logMaxSizeMB: 10,
        enabledModules: [
            "reminders": .readOnly,
            "calendar": .readOnly,
            "mail": .readOnly,
            "messages": .readOnly,
            "notes": .readOnly,
            "contacts": .readOnly,
            "safari": .readOnly,
            "finder": .readOnly,
            "shortcuts": .readOnly,
            "crossapp": .readOnly,
        ],
        confirmationRequired: [
            "send_message": true,
            "send_draft": true,
            "delete_event": true,
            "delete_note": true,
            "close_tab": true,
            "run_shortcut": true,
            "complete_reminder": true,
            "bulk_decline_events": true,
            "bulk_archive_messages": true,
            "delete_bookmark": true,
            "close_tabs_matching": true,
        ]
    )
}
