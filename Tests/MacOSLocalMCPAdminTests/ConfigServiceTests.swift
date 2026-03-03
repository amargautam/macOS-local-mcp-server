import XCTest
@testable import MacOSLocalMCPAdmin

final class ConfigServiceTests: XCTestCase {

    private var tmpDir: URL!
    private var configPath: String { tmpDir.appendingPathComponent("config.json").path }

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConfigServiceTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    private func writeConfig(_ config: AppConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        FileManager.default.createFile(atPath: configPath, contents: data)
    }

    // MARK: - loadConfig

    func test_loadConfig_returnsDefaults_whenFileAbsent() {
        let service = ConfigService(configFilePath: configPath)
        let config = service.loadConfig()
        XCTAssertEqual(config, AppConfig.defaults)
    }

    func test_loadConfig_returnsDefaults_whenFileInvalid() {
        FileManager.default.createFile(
            atPath: configPath,
            contents: "not json".data(using: .utf8)
        )
        let service = ConfigService(configFilePath: configPath)
        let config = service.loadConfig()
        XCTAssertEqual(config, AppConfig.defaults)
    }

    func test_loadConfig_parsesLogLevel() throws {
        let cfg = AppConfig(
            logLevel: "verbose",
            logMaxSizeMB: 10,
            enabledModules: AppConfig.defaults.enabledModules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try writeConfig(cfg)
        let service = ConfigService(configFilePath: configPath)
        XCTAssertEqual(service.loadConfig().logLevel, "verbose")
    }

    func test_loadConfig_parsesEnabledModules() throws {
        var modules = AppConfig.defaults.enabledModules
        modules["reminders"] = .allDisabled
        let cfg = AppConfig(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: modules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try writeConfig(cfg)
        let service = ConfigService(configFilePath: configPath)
        let loaded = service.loadConfig()
        XCTAssertFalse(loaded.enabledModules["reminders"]?.read ?? true)
        XCTAssertFalse(loaded.enabledModules["reminders"]?.write ?? true)
    }

    func test_loadConfig_parsesReadOnlyModule() throws {
        var modules = AppConfig.defaults.enabledModules
        modules["calendar"] = .readOnly
        let cfg = AppConfig(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: modules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try writeConfig(cfg)
        let service = ConfigService(configFilePath: configPath)
        let loaded = service.loadConfig()
        XCTAssertTrue(loaded.enabledModules["calendar"]?.read ?? false)
        XCTAssertFalse(loaded.enabledModules["calendar"]?.write ?? true)
    }

    func test_loadConfig_backwardCompatOldBoolFormat() throws {
        let json = """
        {
            "logLevel": "normal",
            "logMaxSizeMB": 10,
            "enabledModules": {"reminders": true, "calendar": false},
            "confirmationRequired": {}
        }
        """.data(using: .utf8)!
        FileManager.default.createFile(atPath: configPath, contents: json)
        let service = ConfigService(configFilePath: configPath)
        let loaded = service.loadConfig()
        XCTAssertTrue(loaded.enabledModules["reminders"]?.read ?? false)
        XCTAssertTrue(loaded.enabledModules["reminders"]?.write ?? false)
        XCTAssertFalse(loaded.enabledModules["calendar"]?.read ?? true)
    }

    // MARK: - saveConfig

    func test_saveConfig_writesFileToDisk() throws {
        let service = ConfigService(configFilePath: configPath)
        let config = AppConfig.defaults
        try service.saveConfig(config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
    }

    func test_saveConfig_roundTrips() throws {
        let service = ConfigService(configFilePath: configPath)
        let cfg = AppConfig(
            logLevel: "debug",
            logMaxSizeMB: 50,
            enabledModules: AppConfig.defaults.enabledModules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try service.saveConfig(cfg)
        let loaded = service.loadConfig()
        XCTAssertEqual(loaded.logLevel, "debug")
        XCTAssertEqual(loaded.logMaxSizeMB, 50)
    }

    // MARK: - isModuleEnabled

    func test_isModuleEnabled_returnsTrue_forEnabledModule() throws {
        try writeConfig(AppConfig.defaults)
        let service = ConfigService(configFilePath: configPath)
        XCTAssertTrue(service.isModuleEnabled("reminders"))
    }

    func test_isModuleEnabled_returnsFalse_forDisabledModule() throws {
        var modules = AppConfig.defaults.enabledModules
        modules["notes"] = .allDisabled
        let cfg = AppConfig(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: modules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try writeConfig(cfg)
        let service = ConfigService(configFilePath: configPath)
        XCTAssertFalse(service.isModuleEnabled("notes"))
    }

    func test_isModuleEnabled_returnsTrue_forReadOnlyModule() throws {
        var modules = AppConfig.defaults.enabledModules
        modules["notes"] = .readOnly
        let cfg = AppConfig(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: modules,
            confirmationRequired: AppConfig.defaults.confirmationRequired
        )
        try writeConfig(cfg)
        let service = ConfigService(configFilePath: configPath)
        XCTAssertTrue(service.isModuleEnabled("notes"))
    }

    func test_isModuleEnabled_returnsFalse_forUnknownModule() {
        let service = ConfigService(configFilePath: configPath)
        XCTAssertFalse(service.isModuleEnabled("nonexistent_module"))
    }

    // MARK: - setModuleEnabled

    func test_setModuleEnabled_updatesConfig() throws {
        try writeConfig(AppConfig.defaults)
        let service = ConfigService(configFilePath: configPath)
        try service.setModuleEnabled("safari", enabled: false)
        XCTAssertFalse(service.isModuleEnabled("safari"))
    }

    func test_setModuleEnabled_persistsToDisk() throws {
        try writeConfig(AppConfig.defaults)
        let service = ConfigService(configFilePath: configPath)
        try service.setModuleEnabled("contacts", enabled: false)
        let service2 = ConfigService(configFilePath: configPath)
        XCTAssertFalse(service2.isModuleEnabled("contacts"))
    }

    // MARK: - setModuleAccess

    func test_setModuleAccess_setsReadOnly() throws {
        try writeConfig(AppConfig.defaults)
        let service = ConfigService(configFilePath: configPath)
        try service.setModuleAccess("reminders", read: true, write: false)
        let loaded = service.loadConfig()
        XCTAssertTrue(loaded.enabledModules["reminders"]?.read ?? false)
        XCTAssertFalse(loaded.enabledModules["reminders"]?.write ?? true)
    }

    func test_setModuleAccess_persistsToDisk() throws {
        try writeConfig(AppConfig.defaults)
        let service = ConfigService(configFilePath: configPath)
        try service.setModuleAccess("mail", read: true, write: false)
        let service2 = ConfigService(configFilePath: configPath)
        let loaded = service2.loadConfig()
        XCTAssertTrue(loaded.enabledModules["mail"]?.read ?? false)
        XCTAssertFalse(loaded.enabledModules["mail"]?.write ?? true)
    }
}
