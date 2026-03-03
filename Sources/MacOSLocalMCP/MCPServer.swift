import Foundation

/// A tool handler that can be registered with the MCP server.
protocol MCPToolHandler {
    /// The tool name this handler responds to.
    var toolName: String { get }

    /// Handle a tool call with the given arguments and return a result.
    func handle(arguments: [String: JSONValue]?) async throws -> MCPToolResult
}

/// Registry for MCP tools. Tools register themselves here and the server routes calls to them.
final class ToolRegistry {
    /// Registered tool handlers keyed by tool name.
    private var handlers: [String: MCPToolHandler] = [:]

    /// The config manager for checking module/tool status.
    let configManager: ConfigManager

    /// Initialize with a config manager.
    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    /// Register a tool handler.
    func register(_ handler: MCPToolHandler) {
        handlers[handler.toolName] = handler
    }

    /// Register multiple tool handlers.
    func registerAll(_ newHandlers: [MCPToolHandler]) {
        for handler in newHandlers {
            handlers[handler.toolName] = handler
        }
    }

    /// Look up a handler by tool name.
    func handler(for toolName: String) -> MCPToolHandler? {
        return handlers[toolName]
    }

    /// Check if a tool is registered.
    func isRegistered(_ toolName: String) -> Bool {
        return handlers[toolName] != nil
    }

    /// Get all registered tool names.
    var registeredToolNames: [String] {
        return Array(handlers.keys).sorted()
    }
}

/// The MCP server that communicates over JSON-RPC via stdio.
/// Reads stdin line-by-line, parses JSON-RPC requests, routes to tools, sends JSON-RPC responses to stdout.
final class MCPServer {

    /// The server name reported during initialization.
    static let serverName = "macOS Local MCP Server"

    /// The server version reported during initialization.
    static let serverVersion = "0.1.0"

    /// The MCP protocol version supported.
    static let protocolVersion = "2024-11-05"

    /// The tool registry.
    let toolRegistry: ToolRegistry

    /// The config manager.
    let configManager: ConfigManager

    /// The activity logger.
    let activityLogger: ActivityLogger

    /// The heartbeat manager.
    let heartbeatManager: HeartbeatManager

    /// Whether the server has been initialized (received initialize request).
    private(set) var isInitialized: Bool = false

    /// Whether the server is currently running.
    private(set) var isRunning: Bool = false

    /// JSON encoder for responses.
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    /// JSON decoder for requests.
    private let decoder = JSONDecoder()

    /// Custom input for testing (nil means use stdin).
    var inputSource: (() -> String?)? = nil

    /// Custom output for testing (nil means use stdout).
    var outputSink: ((String) -> Void)? = nil

    /// Initialize with default configuration.
    convenience init() {
        let config = ConfigManager()
        self.init(configManager: config)
    }

    /// Initialize with a specific config manager.
    init(configManager: ConfigManager, activityLogger: ActivityLogger? = nil, heartbeatManager: HeartbeatManager? = nil) {
        self.configManager = configManager
        self.toolRegistry = ToolRegistry(configManager: configManager)
        self.activityLogger = activityLogger ?? ActivityLogger()
        self.heartbeatManager = heartbeatManager ?? HeartbeatManager()
    }

    // MARK: - Server Lifecycle

    /// The default PID file path.
    static let defaultPidFilePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp/server.pid"
    }()

    /// Log a message to stderr for diagnostics (visible in Claude Desktop MCP logs).
    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }

    /// Run the server, reading from stdin and writing to stdout.
    func run() {
        isRunning = true
        MCPServer.log("macOS Local MCP Server v\(MCPServer.serverVersion) starting")
        writePidFile()
        heartbeatManager.start()
        MCPServer.log("Server ready, waiting for input on stdin")

        while isRunning {
            guard let line = readLine() else {
                // EOF reached
                MCPServer.log("EOF on stdin, shutting down")
                break
            }
            processLine(line)
        }

        heartbeatManager.stop()
        removePidFile()
        MCPServer.log("Server stopped")
    }

    /// Run the server with custom input/output for testing.
    func runWithTestIO(input: @escaping () -> String?, output: @escaping (String) -> Void) {
        self.inputSource = input
        self.outputSink = output
        isRunning = true

        while isRunning {
            guard let line = input() else {
                break
            }
            processLine(line)
        }
    }

    /// Stop the server.
    func stop() {
        isRunning = false
        heartbeatManager.stop()
        removePidFile()
    }

    // MARK: - PID File

    /// Write the current process PID to `~/.macos-local-mcp/server.pid`.
    /// If a stale PID file exists from a previous crashed run, it is overwritten.
    /// If the PID file belongs to another running process, we skip writing
    /// to avoid clobbering a healthy instance's PID.
    private func writePidFile() {
        let path = MCPServer.defaultPidFilePath
        let directory = (path as NSString).deletingLastPathComponent
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory) {
            try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }

        let currentPid = ProcessInfo.processInfo.processIdentifier

        // Check for an existing PID file
        if let existingRaw = try? String(contentsOfFile: path, encoding: .utf8),
           let existingPid = pid_t(existingRaw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if existingPid == currentPid {
                // Already our PID file, nothing to do
                return
            }
            // Check if the other process is still running
            if kill(existingPid, 0) == 0 {
                MCPServer.log("Another macOS Local MCP instance is running (PID \(existingPid)), skipping PID file write")
                return
            }
            MCPServer.log("Overwriting stale PID file (previous PID: \(existingPid))")
        }

        try? "\(currentPid)".write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Remove the PID file on shutdown, but only if it belongs to the current process.
    /// This prevents a short-lived invocation from removing another instance's PID file.
    private func removePidFile() {
        let path = MCPServer.defaultPidFilePath
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
              let filePid = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        let currentPid = Int(ProcessInfo.processInfo.processIdentifier)
        if filePid == currentPid {
            try? FileManager.default.removeItem(atPath: path)
        } else {
            MCPServer.log("Not removing PID file (belongs to PID \(filePid), we are \(currentPid))")
        }
    }

    // MARK: - Request Processing

    /// Process a single line of input as a JSON-RPC request.
    func processLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let data = trimmed.data(using: .utf8) else {
            sendError(id: nil, error: JSONRPCError(code: .parseError, message: "Invalid UTF-8 input"))
            return
        }

        let request: JSONRPCRequest
        do {
            request = try decoder.decode(JSONRPCRequest.self, from: data)
        } catch {
            sendError(id: nil, error: JSONRPCError(code: .parseError, message: "Parse error: \(error.localizedDescription)"))
            return
        }

        // Validate JSON-RPC version
        guard request.jsonrpc == "2.0" else {
            sendError(id: request.id, error: JSONRPCError(code: .invalidRequest, message: "Invalid JSON-RPC version: expected 2.0"))
            return
        }

        // Route the request
        handleRequest(request)
    }

    /// Route a parsed JSON-RPC request to the appropriate handler.
    func handleRequest(_ request: JSONRPCRequest) {
        switch request.method {
        case "initialize":
            handleInitialize(request)
        case "initialized", "notifications/initialized":
            // Notification from client, no response needed
            break
        case "tools/list", "tools/call":
            // Require initialization before processing tool requests
            guard isInitialized else {
                sendError(id: request.id, error: JSONRPCError(code: .invalidRequest, message: "Server not initialized. Send 'initialize' first."))
                return
            }
            if request.method == "tools/list" {
                handleToolsList(request)
            } else {
                handleToolsCall(request)
            }
        default:
            // Per JSON-RPC spec, notifications (no id) must not receive a response
            if request.id != nil {
                sendError(id: request.id, error: JSONRPCError(code: .methodNotFound, message: "Method not found: \(request.method)"))
            }
        }
    }

    // MARK: - Method Handlers

    /// Handle the initialize request.
    private func handleInitialize(_ request: JSONRPCRequest) {
        isInitialized = true

        let result = MCPInitializeResult(
            protocolVersion: MCPServer.protocolVersion,
            capabilities: MCPServerCapabilities(
                tools: MCPToolsCapability(listChanged: true)
            ),
            serverInfo: MCPServerInfo(
                name: MCPServer.serverName,
                version: MCPServer.serverVersion
            )
        )

        do {
            let resultData = try encoder.encode(result)
            let resultValue = try decoder.decode(JSONValue.self, from: resultData)
            sendResult(id: request.id, result: resultValue)
        } catch {
            sendError(id: request.id, error: JSONRPCError(code: .internalError, message: "Failed to encode initialize result"))
        }
    }

    /// Handle the tools/list request.
    private func handleToolsList(_ request: JSONRPCRequest) {
        let tools = ToolDefinitions.enabledTools(config: configManager)

        do {
            let toolsData = try encoder.encode(["tools": tools])
            let toolsValue = try decoder.decode(JSONValue.self, from: toolsData)
            sendResult(id: request.id, result: toolsValue)
        } catch {
            sendError(id: request.id, error: JSONRPCError(code: .internalError, message: "Failed to encode tools list"))
        }
    }

    /// Handle the tools/call request.
    private func handleToolsCall(_ request: JSONRPCRequest) {
        // Parse the tool call params
        guard let params = request.params,
              let paramsDict = params.objectValue,
              case .string(let toolName) = paramsDict["name"] else {
            sendError(id: request.id, error: JSONRPCError(code: .invalidParams, message: "Missing or invalid 'name' parameter"))
            return
        }

        let arguments = paramsDict["arguments"]?.objectValue

        // Check if the tool's access level is enabled for its module.
        // Default-deny: tools not in the module mapping are blocked.
        guard let module = ToolDefinitions.toolToModule[toolName] else {
            sendError(id: request.id, error: JSONRPCError(code: .toolNotFound, message: "Unknown tool: \(toolName)"))
            return
        }
        let accessLevel = ToolDefinitions.toolAccessLevel[toolName] ?? .write
        guard configManager.isToolAccessEnabled(module: module, accessLevel: accessLevel) else {
            let levelStr = accessLevel == .read ? "read" : "write"
            let result = MCPToolResult.error("Tool '\(toolName)' is disabled (\(levelStr) access for module '\(module)' is disabled)")
            sendToolResult(id: request.id, result: result, errorCode: .toolDisabled)
            return
        }

        // Check if the tool requires confirmation
        if configManager.isConfirmationRequired(tool: toolName) {
            let confirmationProvided = arguments?["confirmation"]
            if case .bool(true) = confirmationProvided {
                // Confirmation provided, proceed
            } else {
                let result = MCPToolResult.error("Tool '\(toolName)' requires confirmation. Pass confirmation: true to proceed.")
                activityLogger.logConfirmationRequired(tool: toolName, params: [:])
                sendToolResult(id: request.id, result: result, errorCode: .confirmationRequired)
                return
            }
        }

        // Look up the tool handler
        guard let handler = toolRegistry.handler(for: toolName) else {
            // Check if the tool exists in definitions but has no handler registered
            let allToolNames = ToolDefinitions.allTools.map { $0.name }
            if allToolNames.contains(toolName) {
                let result = MCPToolResult.error("Tool '\(toolName)' is not yet implemented")
                sendToolResult(id: request.id, result: result, errorCode: .toolNotFound)
            } else {
                sendError(id: request.id, error: JSONRPCError(code: .toolNotFound, message: "Unknown tool: \(toolName)"))
            }
            return
        }

        // Execute the tool with a timeout to prevent blocking the server forever
        let startTime = DispatchTime.now()
        let timeoutSeconds: Int = 55  // Just under Claude Desktop's 60s timeout

        // Use a semaphore to bridge async to sync for the stdio event loop
        let semaphore = DispatchSemaphore(value: 0)
        var toolResult: MCPToolResult?
        var toolError: Error?

        Task {
            do {
                toolResult = try await handler.handle(arguments: arguments)
            } catch {
                toolError = error
            }
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + .seconds(timeoutSeconds))

        let endTime = DispatchTime.now()
        let durationMs = Int((endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)

        if waitResult == .timedOut {
            let result = MCPToolResult.error("Tool '\(toolName)' timed out after \(timeoutSeconds)s. The operation may require a macOS permission — check System Settings > Privacy & Security.")
            activityLogger.logError(tool: toolName, params: [:], durationMs: durationMs, error: "timeout")
            sendToolResult(id: request.id, result: result)
        } else if let error = toolError {
            let result = MCPToolResult.error(error.localizedDescription)
            activityLogger.logError(tool: toolName, params: [:], durationMs: durationMs, error: error.localizedDescription)
            sendToolResult(id: request.id, result: result)
        } else if let result = toolResult {
            let resultCount = result.content.count
            activityLogger.logSuccess(tool: toolName, params: [:], durationMs: durationMs, resultCount: resultCount)
            sendToolResult(id: request.id, result: result)
        }
    }

    // MARK: - Response Sending

    /// Send a successful JSON-RPC response.
    func sendResult(id: JSONRPCId?, result: JSONValue) {
        let response = JSONRPCResponse(id: id, result: result)
        sendResponse(response)
    }

    /// Send a JSON-RPC error response.
    func sendError(id: JSONRPCId?, error: JSONRPCError) {
        let response = JSONRPCResponse(id: id, error: error)
        sendResponse(response)
    }

    /// Send a tool result as a JSON-RPC response.
    private func sendToolResult(id: JSONRPCId?, result: MCPToolResult, errorCode: MCPErrorCode? = nil) {
        do {
            let resultData = try encoder.encode(result)
            let resultValue = try decoder.decode(JSONValue.self, from: resultData)

            if let errorCode = errorCode {
                // Send as error response with the tool result in the data field
                let error = JSONRPCError(code: errorCode, message: result.content.first?.text ?? "Tool error", data: resultValue)
                sendError(id: id, error: error)
            } else {
                sendResult(id: id, result: resultValue)
            }
        } catch {
            sendError(id: id, error: JSONRPCError(code: .internalError, message: "Failed to encode tool result"))
        }
    }

    /// Encode and send a JSON-RPC response.
    private func sendResponse(_ response: JSONRPCResponse) {
        do {
            let data = try encoder.encode(response)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }

            if let sink = outputSink {
                sink(jsonString)
            } else {
                print(jsonString)
                fflush(stdout)
            }
        } catch {
            // Last resort: try to send a minimal error
            let errorJson = "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32603,\"message\":\"Internal encoding error\"}}"
            if let sink = outputSink {
                sink(errorJson)
            } else {
                print(errorJson)
                fflush(stdout)
            }
        }
    }
}
