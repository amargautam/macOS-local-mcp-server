import XCTest
@testable import MacOSLocalMCP

final class ToolRegistryTests: XCTestCase {

    var registry: ToolRegistry!
    var configManager: ConfigManager!

    override func setUp() {
        super.setUp()
        configManager = ConfigManager(config: ConfigData.defaults)
        registry = ToolRegistry(configManager: configManager)
    }

    // MARK: - Register and Lookup

    func testRegisterAndLookupHandler() {
        let handler = MockToolHandler(toolName: "test_tool")
        registry.register(handler)
        XCTAssertNotNil(registry.handler(for: "test_tool"))
    }

    func testLookupUnregisteredHandlerReturnsNil() {
        XCTAssertNil(registry.handler(for: "nonexistent"))
    }

    func testIsRegistered() {
        let handler = MockToolHandler(toolName: "my_tool")
        registry.register(handler)
        XCTAssertTrue(registry.isRegistered("my_tool"))
        XCTAssertFalse(registry.isRegistered("other_tool"))
    }

    func testRegisteredToolNamesSorted() {
        registry.register(MockToolHandler(toolName: "zebra"))
        registry.register(MockToolHandler(toolName: "alpha"))
        registry.register(MockToolHandler(toolName: "middle"))
        let names = registry.registeredToolNames
        XCTAssertEqual(names, ["alpha", "middle", "zebra"])
    }

    func testRegisterAllMultipleHandlers() {
        let handlers: [MCPToolHandler] = [
            MockToolHandler(toolName: "tool_a"),
            MockToolHandler(toolName: "tool_b"),
            MockToolHandler(toolName: "tool_c"),
        ]
        registry.registerAll(handlers)
        XCTAssertEqual(registry.registeredToolNames.count, 3)
        XCTAssertTrue(registry.isRegistered("tool_a"))
        XCTAssertTrue(registry.isRegistered("tool_b"))
        XCTAssertTrue(registry.isRegistered("tool_c"))
    }

    func testRegisterOverwritesPreviousHandler() {
        let handler1 = MockToolHandler(toolName: "tool")
        handler1.resultToReturn = .text("first")
        let handler2 = MockToolHandler(toolName: "tool")
        handler2.resultToReturn = .text("second")
        registry.register(handler1)
        registry.register(handler2)
        let found = registry.handler(for: "tool") as? MockToolHandler
        XCTAssertEqual(found?.resultToReturn.content.first?.text, "second")
    }

    func testEmptyRegistryHasNoTools() {
        XCTAssertEqual(registry.registeredToolNames.count, 0)
        XCTAssertFalse(registry.isRegistered("anything"))
    }

    func testRegistryHoldsConfigManager() {
        XCTAssertTrue(registry.configManager.isModuleEnabled(module: "reminders"))
    }
}
