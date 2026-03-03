import XCTest
@testable import MacOSLocalMCP

final class MCPServerTests: XCTestCase {

    var server: MCPServer!
    var responses: [String]!
    var tempDir: String!

    /// Config with all modules enabled (read + write) for test convenience.
    private static let allEnabledConfig = ConfigData(
        logLevel: "normal",
        logMaxSizeMB: 10,
        enabledModules: [
            "reminders": .allEnabled, "calendar": .allEnabled, "mail": .allEnabled,
            "messages": .allEnabled, "notes": .allEnabled, "contacts": .allEnabled,
            "safari": .allEnabled, "finder": .allEnabled, "shortcuts": .allEnabled,
            "system": .allEnabled,
        ],
        confirmationRequired: [
            "send_message": true, "send_draft": true, "delete_event": true,
            "delete_note": true, "close_tab": true, "toggle_dnd": true,
            "run_shortcut": true, "run_shell": true, "complete_reminder": true,
            "get_clipboard": true, "set_clipboard": true,
        ]
    )

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "macos-local-mcp-server-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        let configManager = ConfigManager(config: MCPServerTests.allEnabledConfig)
        let logger = ActivityLogger(logFilePath: tempDir + "/activity.jsonl")
        let heartbeat = HeartbeatManager(heartbeatFilePath: tempDir + "/heartbeat", intervalSeconds: 999)
        server = MCPServer(configManager: configManager, activityLogger: logger, heartbeatManager: heartbeat)
        responses = []
        server.outputSink = { [weak self] response in
            self?.responses.append(response)
        }
    }

    /// Send initialize to set isInitialized = true (required before tools/* calls).
    private func initializeServer() {
        let request = makeRequest(id: 0, method: "initialize", params: [
            "protocolVersion": "2024-11-05",
            "clientInfo": ["name": "test", "version": "1.0"]
        ])
        server.processLine(request)
        // Clear the initialize response so test indices start fresh
        responses.removeAll()
    }

    override func tearDown() {
        server.stop()
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func parseResponse(_ index: Int = 0) -> [String: Any]? {
        guard index < responses.count,
              let data = responses[index].data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func makeRequest(id: Int, method: String, params: [String: Any]? = nil) -> String {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": method
        ]
        if let params = params {
            request["params"] = params
        }
        let data = try! JSONSerialization.data(withJSONObject: request)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Initialize

    func testInitializeResponse() {
        let request = makeRequest(id: 1, method: "initialize", params: [
            "protocolVersion": "2024-11-05",
            "clientInfo": ["name": "test-client", "version": "1.0"]
        ])
        server.processLine(request)

        let response = parseResponse()
        XCTAssertNotNil(response)
        XCTAssertEqual(response?["jsonrpc"] as? String, "2.0")

        let result = response?["result"] as? [String: Any]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["protocolVersion"] as? String, "2024-11-05")

        let serverInfo = result?["serverInfo"] as? [String: Any]
        XCTAssertEqual(serverInfo?["name"] as? String, "macOS Local MCP Server")
        XCTAssertEqual(serverInfo?["version"] as? String, "0.1.0")
    }

    func testInitializeSetsIsInitialized() {
        XCTAssertFalse(server.isInitialized)
        let request = makeRequest(id: 1, method: "initialize")
        server.processLine(request)
        XCTAssertTrue(server.isInitialized)
    }

    func testInitializeResponseContainsCapabilities() {
        let request = makeRequest(id: 1, method: "initialize")
        server.processLine(request)

        let result = parseResponse()?["result"] as? [String: Any]
        let capabilities = result?["capabilities"] as? [String: Any]
        XCTAssertNotNil(capabilities)
        let tools = capabilities?["tools"] as? [String: Any]
        XCTAssertEqual(tools?["listChanged"] as? Bool, true)
    }

    // MARK: - tools/list

    func testToolsListReturnsAllEnabledTools() {
        initializeServer()
        let request = makeRequest(id: 2, method: "tools/list")
        server.processLine(request)

        let result = parseResponse()?["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        XCTAssertNotNil(tools)
        XCTAssertGreaterThan(tools?.count ?? 0, 0)

        // Every tool should have name, description, inputSchema
        if let firstTool = tools?.first {
            XCTAssertNotNil(firstTool["name"])
            XCTAssertNotNil(firstTool["description"])
            XCTAssertNotNil(firstTool["inputSchema"])
        }
    }

    // MARK: - tools/call

    func testToolsCallRoutesToRegisteredHandler() {
        initializeServer()
        let handler = MockToolHandler(toolName: "list_reminder_lists")
        handler.resultToReturn = .text("mock reminders")
        server.toolRegistry.register(handler)

        let request = makeRequest(id: 3, method: "tools/call", params: [
            "name": "list_reminder_lists"
        ])
        server.processLine(request)

        XCTAssertTrue(handler.handleCalled)
        let result = parseResponse()?["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, "mock reminders")
    }

    func testToolsCallPassesArguments() {
        initializeServer()
        let handler = MockToolHandler(toolName: "search_reminders")
        server.toolRegistry.register(handler)

        let request = makeRequest(id: 4, method: "tools/call", params: [
            "name": "search_reminders",
            "arguments": ["query": "groceries"]
        ])
        server.processLine(request)

        XCTAssertTrue(handler.handleCalled)
        XCTAssertEqual(handler.lastArguments?["query"], .string("groceries"))
    }

    func testToolsCallUnregisteredToolReturnsError() {
        initializeServer()
        let request = makeRequest(id: 5, method: "tools/call", params: [
            "name": "list_reminder_lists"
        ])
        server.processLine(request)

        let response = parseResponse()
        let error = response?["error"] as? [String: Any]
        XCTAssertNotNil(error)
    }

    func testToolsCallUnknownToolReturnsError() {
        initializeServer()
        let request = makeRequest(id: 6, method: "tools/call", params: [
            "name": "completely_unknown_tool"
        ])
        server.processLine(request)

        let response = parseResponse()
        let error = response?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.toolNotFound.rawValue)
    }

    func testToolsCallMissingNameParam() {
        initializeServer()
        let request = makeRequest(id: 7, method: "tools/call", params: [:])
        server.processLine(request)

        let response = parseResponse()
        let error = response?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.invalidParams.rawValue)
    }

    // MARK: - Module Disabled

    func testToolsCallDisabledModuleReturnsError() {
        let configData = ConfigData(
            logLevel: "normal",
            logMaxSizeMB: 10,
            enabledModules: ["reminders": .allDisabled],
            confirmationRequired: [:]
        )
        let configManager = ConfigManager(config: configData)
        let disabledServer = MCPServer(
            configManager: configManager,
            activityLogger: ActivityLogger(logFilePath: tempDir + "/activity2.jsonl"),
            heartbeatManager: HeartbeatManager(heartbeatFilePath: tempDir + "/hb2", intervalSeconds: 999)
        )
        var disabledResponses: [String] = []
        disabledServer.outputSink = { disabledResponses.append($0) }

        // Initialize first
        let initRequest = makeRequest(id: 0, method: "initialize")
        disabledServer.processLine(initRequest)
        disabledResponses.removeAll()

        let handler = MockToolHandler(toolName: "list_reminder_lists")
        disabledServer.toolRegistry.register(handler)

        let request = makeRequest(id: 8, method: "tools/call", params: [
            "name": "list_reminder_lists"
        ])
        disabledServer.processLine(request)

        XCTAssertFalse(handler.handleCalled)
        guard let data = disabledResponses.first?.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("No response")
            return
        }
        let error = json["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.toolDisabled.rawValue)
    }

    // MARK: - Confirmation Required

    func testToolsCallConfirmationRequiredWithoutConfirmation() {
        initializeServer()
        let handler = MockToolHandler(toolName: "send_message")
        server.toolRegistry.register(handler)

        let request = makeRequest(id: 9, method: "tools/call", params: [
            "name": "send_message",
            "arguments": ["to": "+1234567890", "body": "hello"]
        ])
        server.processLine(request)

        XCTAssertFalse(handler.handleCalled)
        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.confirmationRequired.rawValue)
    }

    func testToolsCallConfirmationRequiredWithConfirmation() {
        initializeServer()
        let handler = MockToolHandler(toolName: "send_message")
        server.toolRegistry.register(handler)

        let request = makeRequest(id: 10, method: "tools/call", params: [
            "name": "send_message",
            "arguments": ["to": "+1234567890", "body": "hello", "confirmation": true]
        ])
        server.processLine(request)

        XCTAssertTrue(handler.handleCalled)
    }

    // MARK: - Error Handling

    func testParseErrorOnInvalidJSON() {
        server.processLine("this is not json")

        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.parseError.rawValue)
    }

    func testInvalidJsonRpcVersion() {
        let json = "{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"test\"}"
        server.processLine(json)

        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.invalidRequest.rawValue)
    }

    func testMethodNotFound() {
        let request = makeRequest(id: 11, method: "nonexistent/method")
        server.processLine(request)

        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.methodNotFound.rawValue)
    }

    func testEmptyLineIgnored() {
        server.processLine("")
        server.processLine("   ")
        XCTAssertTrue(responses.isEmpty)
    }

    func testInitializedNotificationNoResponse() {
        let request = makeRequest(id: 12, method: "initialized")
        server.processLine(request)
        XCTAssertTrue(responses.isEmpty)
    }

    func testNotificationsInitializedNoResponse() {
        let request = makeRequest(id: 13, method: "notifications/initialized")
        server.processLine(request)
        XCTAssertTrue(responses.isEmpty)
    }

    /// Claude Desktop sends notifications/initialized as a true JSON-RPC notification
    /// (no id field). The server MUST NOT send any response — not even an error.
    func testNotificationsInitializedTrueNotificationNoResponse() {
        let json = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"
        server.processLine(json)
        XCTAssertTrue(responses.isEmpty, "Server must not respond to notifications/initialized notification")
    }

    /// Claude Desktop sends initialized (without namespace) as a notification too.
    func testInitializedTrueNotificationNoResponse() {
        let json = "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\"}"
        server.processLine(json)
        XCTAssertTrue(responses.isEmpty, "Server must not respond to initialized notification")
    }

    func testNotificationWithoutIdNoResponse() {
        // Notification = request without id; server must not respond even for unknown methods
        let json = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/some_unknown\"}"
        server.processLine(json)
        XCTAssertTrue(responses.isEmpty)
    }

    /// Simulate the exact sequence Claude Desktop uses on connect:
    /// initialize (with id) → notifications/initialized (no id) → tools/list (with id)
    /// The server must respond only to initialize and tools/list, never to the notification.
    func testFullClaudeDesktopHandshakeSequence() {
        // Step 1: initialize
        let initRequest = makeRequest(id: 0, method: "initialize", params: [
            "protocolVersion": "2025-11-25",
            "clientInfo": ["name": "claude-ai", "version": "0.1.0"]
        ])
        server.processLine(initRequest)
        XCTAssertEqual(responses.count, 1, "initialize must produce exactly one response")

        let initResponse = parseResponse(0)
        XCTAssertNotNil(initResponse?["result"], "initialize response must have a result")
        XCTAssertNil(initResponse?["error"], "initialize response must not have an error")

        // Step 2: notifications/initialized (true notification, no id) — must produce no response
        let notifJson = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}"
        server.processLine(notifJson)
        XCTAssertEqual(responses.count, 1, "notifications/initialized must produce no additional response")

        // Step 3: tools/list
        let toolsListRequest = makeRequest(id: 1, method: "tools/list", params: [:])
        server.processLine(toolsListRequest)
        XCTAssertEqual(responses.count, 2, "tools/list must produce exactly one response")

        let toolsResponse = parseResponse(1)
        XCTAssertNotNil(toolsResponse?["result"], "tools/list response must have a result")
        XCTAssertNil(toolsResponse?["error"], "tools/list response must not have an error")

        let tools = (toolsResponse?["result"] as? [String: Any])?["tools"] as? [[String: Any]]
        XCTAssertNotNil(tools, "tools/list result must contain a tools array")
        XCTAssertGreaterThan(tools?.count ?? 0, 0, "tools array must be non-empty")
    }

    // MARK: - Tool Handler Error

    func testToolHandlerThrowsError() {
        initializeServer()
        let handler = MockToolHandler(toolName: "list_calendars")
        handler.errorToThrow = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied"])
        server.toolRegistry.register(handler)

        let request = makeRequest(id: 13, method: "tools/call", params: [
            "name": "list_calendars"
        ])
        server.processLine(request)

        let result = parseResponse()?["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["text"] as? String, "Calendar access denied")
    }

    // MARK: - Server Lifecycle

    func testServerStaticProperties() {
        XCTAssertEqual(MCPServer.serverName, "macOS Local MCP Server")
        XCTAssertEqual(MCPServer.serverVersion, "0.1.0")
        XCTAssertEqual(MCPServer.protocolVersion, "2024-11-05")
    }

    /// A stale PID file from a previous crashed run must not prevent the server from starting.
    /// The server must be able to run an initialize handshake even when a stale PID file exists.
    func testStalePidFileDoesNotPreventNormalOperation() {
        // Write a fake stale PID to the default path to simulate a previous crash
        let pidPath = MCPServer.defaultPidFilePath
        let pidDirectory = (pidPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: pidDirectory, withIntermediateDirectories: true)
        let stalePid: Int32 = 99999
        try? "\(stalePid)".write(toFile: pidPath, atomically: true, encoding: .utf8)

        // The server in setUp uses the default PID path.
        // Process an initialize request -- if the stale PID caused any crash or error,
        // we would not get a valid response.
        let request = makeRequest(id: 1, method: "initialize", params: [
            "protocolVersion": "2025-11-25",
            "clientInfo": ["name": "test", "version": "1.0"]
        ])
        server.processLine(request)

        let response = parseResponse(0)
        XCTAssertNotNil(response, "Server must respond to initialize even if a stale PID file exists")
        XCTAssertNotNil(response?["result"], "initialize response must have a result despite stale PID")
        XCTAssertNil(response?["error"], "initialize response must not have an error despite stale PID")
    }

    func testRunWithTestIOProcessesInput() {
        let configManager = ConfigManager(config: ConfigData.defaults)
        let testServer = MCPServer(
            configManager: configManager,
            activityLogger: ActivityLogger(logFilePath: tempDir + "/activity3.jsonl"),
            heartbeatManager: HeartbeatManager(heartbeatFilePath: tempDir + "/hb3", intervalSeconds: 999)
        )
        var capturedResponses: [String] = []
        let inputLines = [
            makeRequest(id: 1, method: "initialize"),
            nil as String?
        ]
        var index = 0

        testServer.runWithTestIO(
            input: {
                guard index < inputLines.count else { return nil }
                let line = inputLines[index]
                index += 1
                return line
            },
            output: { capturedResponses.append($0) }
        )

        XCTAssertEqual(capturedResponses.count, 1)
        XCTAssertTrue(testServer.isInitialized)
    }

    func testToolsCallBeforeInitializeReturnsError() {
        // Don't call initializeServer()
        let request = makeRequest(id: 1, method: "tools/call", params: [
            "name": "list_reminder_lists"
        ])
        server.processLine(request)

        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.invalidRequest.rawValue)
    }

    func testToolsListBeforeInitializeReturnsError() {
        let request = makeRequest(id: 1, method: "tools/list")
        server.processLine(request)

        let error = parseResponse()?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual(error?["code"] as? Int, MCPErrorCode.invalidRequest.rawValue)
    }

    func testStopSetsIsRunningFalse() {
        server.stop()
        XCTAssertFalse(server.isRunning)
    }

    func testToolsListIncludesAnnotations() {
        initializeServer()
        let request = makeRequest(id: 14, method: "tools/list")
        server.processLine(request)

        let result = parseResponse()?["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        XCTAssertNotNil(tools)
        if let firstTool = tools?.first {
            let annotations = firstTool["annotations"] as? [String: Any]
            XCTAssertNotNil(annotations, "Tool should include annotations")
            XCTAssertNotNil(annotations?["readOnlyHint"])
        }
    }

    // MARK: - Response Format

    func testResponseIdMatchesRequestId() {
        let request = makeRequest(id: 42, method: "initialize")
        server.processLine(request)

        let response = parseResponse()
        XCTAssertEqual(response?["id"] as? Int, 42)
    }

    func testResponseHasJsonrpc2() {
        let request = makeRequest(id: 1, method: "initialize")
        server.processLine(request)

        let response = parseResponse()
        XCTAssertEqual(response?["jsonrpc"] as? String, "2.0")
    }
}
