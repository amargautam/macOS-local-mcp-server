import Foundation

// MARK: - Protocol

/// Reads and writes the macOS Local MCP configuration file.
public protocol ConfigServicing {
    /// Load the current configuration from disk. Returns defaults if the file is absent or invalid.
    func loadConfig() -> AppConfig
    /// Write the configuration to disk.
    func saveConfig(_ config: AppConfig) throws
    /// Whether a named module has any access enabled (read or write).
    func isModuleEnabled(_ module: String) -> Bool
    /// Enable or disable a named module (sets both read and write), persisting the change to disk.
    func setModuleEnabled(_ module: String, enabled: Bool) throws
    /// Set read/write access for a module, persisting the change to disk.
    func setModuleAccess(_ module: String, read: Bool, write: Bool) throws
}

// MARK: - Concrete Implementation

/// Reads and writes `config.json` in the macOS Local MCP data directory.
public final class ConfigService: ConfigServicing {

    private let configFilePath: String

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Init

    public convenience init() {
        let base = ServerMonitor.defaultDataDirectory
        self.init(configFilePath: "\(base)/config.json")
    }

    public init(configFilePath: String) {
        self.configFilePath = configFilePath
    }

    // MARK: - ConfigServicing

    public func loadConfig() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFilePath),
              let data = FileManager.default.contents(atPath: configFilePath) else {
            return AppConfig.defaults
        }
        return (try? decoder.decode(AppConfig.self, from: data)) ?? AppConfig.defaults
    }

    public func saveConfig(_ config: AppConfig) throws {
        let data = try encoder.encode(config)
        let directory = (configFilePath as NSString).deletingLastPathComponent
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory) {
            try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        try data.write(to: URL(fileURLWithPath: configFilePath), options: .atomic)
    }

    public func isModuleEnabled(_ module: String) -> Bool {
        guard let access = loadConfig().enabledModules[module] else { return false }
        return access.read || access.write
    }

    public func setModuleEnabled(_ module: String, enabled: Bool) throws {
        var config = loadConfig()
        config.enabledModules[module] = enabled
            ? .allEnabled
            : .allDisabled
        try saveConfig(config)
    }

    public func setModuleAccess(_ module: String, read: Bool, write: Bool) throws {
        var config = loadConfig()
        config.enabledModules[module] = AppModuleAccess(read: read, write: write)
        try saveConfig(config)
    }
}
