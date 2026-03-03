import XCTest
@testable import MacOSLocalMCP

final class ConfigManagerTests: XCTestCase {

    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "macos-local-mcp-tests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Default Config

    func testDefaultConfigHasAllModulesReadOnly() {
        let config = ConfigData.defaults
        for (key, access) in config.enabledModules {
            XCTAssertTrue(access.read, "Module \(key) should have read enabled")
            XCTAssertFalse(access.write, "Module \(key) should default to write disabled (read-only)")
        }
    }

    func testDefaultConfigHasAllTenModules() {
        let config = ConfigData.defaults
        let expectedModules = ["reminders", "calendar", "mail", "messages", "notes", "contacts", "safari", "finder", "shortcuts", "crossapp"]
        for module in expectedModules {
            XCTAssertNotNil(config.enabledModules[module], "Missing module: \(module)")
        }
        XCTAssertNil(config.enabledModules["system"], "system module should not be present")
    }

    func testDefaultConfigLogLevel() {
        XCTAssertEqual(ConfigData.defaults.logLevel, "normal")
    }

    func testDefaultConfigLogMaxSize() {
        XCTAssertEqual(ConfigData.defaults.logMaxSizeMB, 10)
    }

    func testDefaultConfigConfirmationRequired() {
        let config = ConfigData.defaults
        XCTAssertTrue(config.confirmationRequired["send_message"] ?? false)
        XCTAssertTrue(config.confirmationRequired["send_draft"] ?? false)
        XCTAssertTrue(config.confirmationRequired["delete_event"] ?? false)
        XCTAssertTrue(config.confirmationRequired["run_shortcut"] ?? false)
    }

    // MARK: - ModuleAccess

    func testModuleAccessAllEnabled() {
        let access = ModuleAccess.allEnabled
        XCTAssertTrue(access.read)
        XCTAssertTrue(access.write)
    }

    func testModuleAccessReadOnly() {
        let access = ModuleAccess.readOnly
        XCTAssertTrue(access.read)
        XCTAssertFalse(access.write)
    }

    func testModuleAccessAllDisabled() {
        let access = ModuleAccess.allDisabled
        XCTAssertFalse(access.read)
        XCTAssertFalse(access.write)
    }

    func testModuleAccessDecodesFromBool() throws {
        let json = "true".data(using: .utf8)!
        let access = try JSONDecoder().decode(ModuleAccess.self, from: json)
        XCTAssertTrue(access.read)
        XCTAssertTrue(access.write)
    }

    func testModuleAccessDecodesFromBoolFalse() throws {
        let json = "false".data(using: .utf8)!
        let access = try JSONDecoder().decode(ModuleAccess.self, from: json)
        XCTAssertFalse(access.read)
        XCTAssertFalse(access.write)
    }

    func testModuleAccessDecodesFromObject() throws {
        let json = """
        {"read": true, "write": false}
        """.data(using: .utf8)!
        let access = try JSONDecoder().decode(ModuleAccess.self, from: json)
        XCTAssertTrue(access.read)
        XCTAssertFalse(access.write)
    }

    func testModuleAccessEncodesAsObject() throws {
        let access = ModuleAccess.readOnly
        let data = try JSONEncoder().encode(access)
        let json = try JSONDecoder().decode([String: Bool].self, from: data)
        XCTAssertEqual(json["read"], true)
        XCTAssertEqual(json["write"], false)
    }

    // MARK: - Backward Compatibility

    func testConfigDataDecodesOldBoolFormat() throws {
        let json = """
        {
            "logLevel": "normal",
            "logMaxSizeMB": 10,
            "enabledModules": {
                "reminders": true,
                "calendar": false
            },
            "confirmationRequired": {}
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(ConfigData.self, from: json)
        XCTAssertTrue(config.enabledModules["reminders"]?.read ?? false)
        XCTAssertTrue(config.enabledModules["reminders"]?.write ?? false)
        XCTAssertFalse(config.enabledModules["calendar"]?.read ?? true)
        XCTAssertFalse(config.enabledModules["calendar"]?.write ?? true)
    }

    func testConfigDataDecodesNewObjectFormat() throws {
        let json = """
        {
            "logLevel": "normal",
            "logMaxSizeMB": 10,
            "enabledModules": {
                "reminders": {"read": true, "write": false},
                "calendar": {"read": false, "write": false}
            },
            "confirmationRequired": {}
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(ConfigData.self, from: json)
        XCTAssertTrue(config.enabledModules["reminders"]?.read ?? false)
        XCTAssertFalse(config.enabledModules["reminders"]?.write ?? true)
        XCTAssertFalse(config.enabledModules["calendar"]?.read ?? true)
    }

    // MARK: - ConfigManager Init

    func testConfigManagerWithCustomConfig() {
        let customConfig = ConfigData(
            logLevel: "debug",
            logMaxSizeMB: 50,
            enabledModules: ["reminders": .allEnabled, "calendar": .allDisabled],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: customConfig)
        XCTAssertEqual(manager.logLevel, "debug")
        XCTAssertEqual(manager.logMaxSizeMB, 50)
    }

    func testConfigManagerDefaultInit() {
        let manager = ConfigManager()
        XCTAssertFalse(manager.logLevel.isEmpty)
    }

    // MARK: - isModuleEnabled

    func testIsModuleEnabledTrue() {
        let manager = ConfigManager(config: ConfigData.defaults)
        XCTAssertTrue(manager.isModuleEnabled(module: "reminders"))
        XCTAssertTrue(manager.isModuleEnabled(module: "calendar"))
    }

    func testIsModuleEnabledFalse() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .allDisabled],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertFalse(manager.isModuleEnabled(module: "reminders"))
    }

    func testIsModuleEnabledReadOnly() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .readOnly],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertTrue(manager.isModuleEnabled(module: "reminders"))
    }

    func testIsModuleEnabledMissingModule() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [:],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertFalse(manager.isModuleEnabled(module: "nonexistent"))
    }

    // MARK: - isToolAccessEnabled

    func testIsToolAccessEnabledReadTrue() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .readOnly],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .read))
    }

    func testIsToolAccessEnabledWriteFalseForReadOnly() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .readOnly],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertFalse(manager.isToolAccessEnabled(module: "reminders", accessLevel: .write))
    }

    func testIsToolAccessEnabledBothTrue() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .allEnabled],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .read))
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .write))
    }

    func testIsToolAccessEnabledMissingModule() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [:],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertFalse(manager.isToolAccessEnabled(module: "nonexistent", accessLevel: .read))
    }

    // MARK: - isConfirmationRequired

    func testIsConfirmationRequiredTrue() {
        let manager = ConfigManager(config: ConfigData.defaults)
        XCTAssertTrue(manager.isConfirmationRequired(tool: "send_message"))
        XCTAssertTrue(manager.isConfirmationRequired(tool: "run_shortcut"))
    }

    func testIsConfirmationRequiredFalse() {
        let manager = ConfigManager(config: ConfigData.defaults)
        XCTAssertFalse(manager.isConfirmationRequired(tool: "list_reminders"))
    }

    func testIsConfirmationRequiredMissingTool() {
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [:],
            confirmationRequired: [:]
        )
        let manager = ConfigManager(config: config)
        XCTAssertFalse(manager.isConfirmationRequired(tool: "nonexistent"))
    }

    // MARK: - Load from File

    func testLoadFromValidFile() throws {
        let configData = ConfigData(
            logLevel: "verbose",
            logMaxSizeMB: 25,
            enabledModules: ["reminders": .allEnabled, "calendar": .allDisabled],
            confirmationRequired: ["send_message": true]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(configData)
        let filePath = tempDir + "/config.json"
        FileManager.default.createFile(atPath: filePath, contents: data)

        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertEqual(manager.logLevel, "verbose")
        XCTAssertEqual(manager.logMaxSizeMB, 25)
        XCTAssertTrue(manager.isModuleEnabled(module: "reminders"))
        XCTAssertFalse(manager.isModuleEnabled(module: "calendar"))
    }

    func testLoadFromOldBoolFormatFile() throws {
        let json = """
        {
            "logLevel": "normal",
            "logMaxSizeMB": 10,
            "enabledModules": {"reminders": true, "calendar": false},
            "confirmationRequired": {}
        }
        """.data(using: .utf8)!
        let filePath = tempDir + "/config.json"
        FileManager.default.createFile(atPath: filePath, contents: json)

        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .read))
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .write))
        XCTAssertFalse(manager.isToolAccessEnabled(module: "calendar", accessLevel: .read))
    }

    func testLoadFromNewObjectFormatFile() throws {
        let json = """
        {
            "logLevel": "normal",
            "logMaxSizeMB": 10,
            "enabledModules": {"reminders": {"read": true, "write": false}},
            "confirmationRequired": {}
        }
        """.data(using: .utf8)!
        let filePath = tempDir + "/config.json"
        FileManager.default.createFile(atPath: filePath, contents: json)

        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertTrue(manager.isToolAccessEnabled(module: "reminders", accessLevel: .read))
        XCTAssertFalse(manager.isToolAccessEnabled(module: "reminders", accessLevel: .write))
    }

    func testLoadFromMissingFileReturnsDefaults() {
        let filePath = tempDir + "/nonexistent.json"
        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertEqual(manager.logLevel, ConfigData.defaults.logLevel)
        XCTAssertEqual(manager.logMaxSizeMB, ConfigData.defaults.logMaxSizeMB)
    }

    func testLoadFromInvalidJSONReturnsDefaults() {
        let filePath = tempDir + "/bad.json"
        FileManager.default.createFile(atPath: filePath, contents: "not json".data(using: .utf8))
        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertEqual(manager.logLevel, ConfigData.defaults.logLevel)
    }

    // MARK: - Reload

    func testReloadUpdatesConfig() throws {
        let filePath = tempDir + "/config.json"
        let initialConfig = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .allEnabled],
            confirmationRequired: [:]
        )
        let encoder = JSONEncoder()
        var data = try encoder.encode(initialConfig)
        FileManager.default.createFile(atPath: filePath, contents: data)

        let manager = ConfigManager(configFilePath: filePath)
        XCTAssertEqual(manager.logLevel, "normal")

        let updatedConfig = ConfigData(
            logLevel: "debug",
            logMaxSizeMB: 20,
            enabledModules: ["reminders": .allDisabled],
            confirmationRequired: [:]
        )
        data = try encoder.encode(updatedConfig)
        try data.write(to: URL(fileURLWithPath: filePath))

        manager.reload(from: filePath)
        XCTAssertEqual(manager.logLevel, "debug")
        XCTAssertFalse(manager.isModuleEnabled(module: "reminders"))
    }

    func testReloadCallbackInvoked() throws {
        let filePath = tempDir + "/config.json"
        let config = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: [:],
            confirmationRequired: [:]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        FileManager.default.createFile(atPath: filePath, contents: data)

        let manager = ConfigManager(configFilePath: filePath)
        var callbackInvoked = false
        manager.onConfigReload = { _ in
            callbackInvoked = true
        }
        manager.reload(from: filePath)
        XCTAssertTrue(callbackInvoked)
    }

    // MARK: - ConfigData Equatable

    func testConfigDataEquatable() {
        let a = ConfigData.defaults
        let b = ConfigData.defaults
        XCTAssertEqual(a, b)
    }

    // MARK: - ensureConfigDirectory / writeDefaultConfigIfNeeded

    func testEnsureConfigDirectoryCreatesDir() throws {
        XCTAssertNoThrow(try ConfigManager.ensureConfigDirectory())
    }
}
