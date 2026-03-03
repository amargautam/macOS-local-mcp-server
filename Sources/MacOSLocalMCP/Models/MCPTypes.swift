import Foundation

// MARK: - MCP Error Codes

/// Standard JSON-RPC and MCP-specific error codes.
enum MCPErrorCode: Int, Codable {
    // Standard JSON-RPC error codes
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603

    // MCP-specific error codes
    case toolNotFound = -31000
    case toolDisabled = -31001
    case confirmationRequired = -31002
    case permissionDenied = -31003
}

// MARK: - JSON-RPC Types

/// A JSON-RPC 2.0 request object.
struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let method: String
    let params: JSONValue?

    init(jsonrpc: String = "2.0", id: JSONRPCId? = nil, method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 response object.
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let result: JSONValue?
    let error: JSONRPCError?

    init(id: JSONRPCId?, result: JSONValue) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    init(id: JSONRPCId?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

/// A JSON-RPC 2.0 error object.
struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: JSONValue?

    init(code: MCPErrorCode, message: String, data: JSONValue? = nil) {
        self.code = code.rawValue
        self.message = message
        self.data = data
    }

    init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// Represents a JSON-RPC request ID, which can be a string or an integer.
enum JSONRPCId: Codable, Equatable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String for JSON-RPC id")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
}

// MARK: - MCP Initialize Types

/// Parameters for the initialize method.
struct MCPInitializeParams: Codable {
    let protocolVersion: String?
    let capabilities: MCPClientCapabilities?
    let clientInfo: MCPClientInfo?
}

/// Client capabilities sent during initialize.
struct MCPClientCapabilities: Codable {
    let roots: MCPRootsCapability?
    let sampling: JSONValue?
}

/// Roots capability.
struct MCPRootsCapability: Codable {
    let listChanged: Bool?
}

/// Client info sent during initialize.
struct MCPClientInfo: Codable {
    let name: String?
    let version: String?
}

/// Result returned from the initialize method.
struct MCPInitializeResult: Codable {
    let protocolVersion: String
    let capabilities: MCPServerCapabilities
    let serverInfo: MCPServerInfo
}

/// Server capabilities advertised during initialize.
struct MCPServerCapabilities: Codable {
    let tools: MCPToolsCapability?

    init(tools: MCPToolsCapability? = nil) {
        self.tools = tools
    }
}

/// Tools capability object.
struct MCPToolsCapability: Codable {
    let listChanged: Bool?

    init(listChanged: Bool? = nil) {
        self.listChanged = listChanged
    }
}

/// Server identification info.
struct MCPServerInfo: Codable {
    let name: String
    let version: String
}

// MARK: - MCP Tool Types

/// Annotations providing hints about a tool's behavior.
/// Used by clients (e.g., Claude Desktop) to categorize tools as read-only, write, or destructive.
struct MCPToolAnnotations: Codable {
    /// If true, the tool does not modify its environment.
    let readOnlyHint: Bool?
    /// If true, the tool may perform destructive updates (delete, overwrite, send).
    let destructiveHint: Bool?
    /// If true, calling repeatedly with the same arguments has no additional effect.
    let idempotentHint: Bool?
    /// If true, the tool interacts with external entities beyond the local environment.
    let openWorldHint: Bool?

    init(readOnlyHint: Bool? = nil, destructiveHint: Bool? = nil, idempotentHint: Bool? = nil, openWorldHint: Bool? = nil) {
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }
}

/// Defines an MCP tool that can be called by the client.
struct MCPToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: MCPToolInputSchema
    let annotations: MCPToolAnnotations?

    init(name: String, description: String, inputSchema: MCPToolInputSchema, annotations: MCPToolAnnotations? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.annotations = annotations
    }
}

/// JSON Schema for tool input parameters.
struct MCPToolInputSchema: Codable {
    let type: String
    let properties: [String: MCPToolParameter]?
    let required: [String]?

    init(type: String = "object", properties: [String: MCPToolParameter]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// A single tool parameter definition.
struct MCPToolParameter: Codable {
    let type: String
    let description: String?
    let `enum`: [String]?
    let items: MCPToolParameterItems?
    let `default`: JSONValue?

    init(type: String, description: String? = nil, enum enumValues: [String]? = nil, items: MCPToolParameterItems? = nil, default defaultValue: JSONValue? = nil) {
        self.type = type
        self.description = description
        self.`enum` = enumValues
        self.items = items
        self.`default` = defaultValue
    }

    enum CodingKeys: String, CodingKey {
        case type, description, items
        case `enum` = "enum"
        case `default` = "default"
    }
}

/// Items definition for array-type parameters.
struct MCPToolParameterItems: Codable {
    let type: String
}

/// Parameters for tools/call method.
struct MCPToolCallParams: Codable {
    let name: String
    let arguments: [String: JSONValue]?
}

/// Result returned from a tool call.
struct MCPToolResult: Codable {
    let content: [MCPToolResultContent]
    let isError: Bool?

    init(content: [MCPToolResultContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }

    /// Convenience initializer for a single text result.
    static func text(_ text: String) -> MCPToolResult {
        MCPToolResult(content: [MCPToolResultContent(type: "text", text: text)])
    }

    /// Convenience initializer for an error result.
    static func error(_ message: String) -> MCPToolResult {
        MCPToolResult(content: [MCPToolResultContent(type: "text", text: message)], isError: true)
    }
}

/// A single content item in a tool result.
struct MCPToolResultContent: Codable {
    let type: String
    let text: String?

    init(type: String, text: String? = nil) {
        self.type = type
        self.text = text
    }
}

// MARK: - JSONValue

/// A type-erased JSON value that supports Codable.
enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }
        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode JSONValue")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Convert a [String: Any] dictionary to JSONValue.
    static func from(dictionary: [String: Any]) -> JSONValue {
        var result: [String: JSONValue] = [:]
        for (key, value) in dictionary {
            result[key] = JSONValue.from(any: value)
        }
        return .object(result)
    }

    /// Convert an array of [String: Any] to JSONValue.
    static func from(arrayOfDictionaries: [[String: Any]]) -> JSONValue {
        .array(arrayOfDictionaries.map { JSONValue.from(dictionary: $0) })
    }

    /// Convert any Swift value to JSONValue.
    static func from(any value: Any) -> JSONValue {
        switch value {
        case let s as String:
            return .string(s)
        case let i as Int:
            return .int(i)
        case let d as Double:
            return .double(d)
        case let b as Bool:
            return .bool(b)
        case let arr as [Any]:
            return .array(arr.map { JSONValue.from(any: $0) })
        case let dict as [String: Any]:
            return .from(dictionary: dict)
        case is NSNull:
            return .null
        default:
            return .string(String(describing: value))
        }
    }

    /// Extract a string value from a JSONValue object by key.
    func stringValue(forKey key: String) -> String? {
        guard case .object(let dict) = self,
              case .string(let value) = dict[key] else {
            return nil
        }
        return value
    }

    /// Extract an int value from a JSONValue object by key.
    func intValue(forKey key: String) -> Int? {
        guard case .object(let dict) = self,
              case .int(let value) = dict[key] else {
            return nil
        }
        return value
    }

    /// Extract a bool value from a JSONValue object by key.
    func boolValue(forKey key: String) -> Bool? {
        guard case .object(let dict) = self,
              case .bool(let value) = dict[key] else {
            return nil
        }
        return value
    }

    /// Extract an object value from a JSONValue.
    var objectValue: [String: JSONValue]? {
        guard case .object(let dict) = self else { return nil }
        return dict
    }

    /// Extract an array value from a JSONValue.
    var arrayValue: [JSONValue]? {
        guard case .array(let arr) = self else { return nil }
        return arr
    }

    /// Convert JSONValue to [String: JSONValue] dictionary (for arguments).
    func toDictionary() -> [String: JSONValue]? {
        guard case .object(let dict) = self else { return nil }
        return dict
    }
}
