import Foundation

/// A tool handler that delegates to a closure for flexible, lightweight registration.
struct ClosureToolHandler: MCPToolHandler {
    let toolName: String
    private let closure: ([String: JSONValue]?) async throws -> MCPToolResult

    init(toolName: String, handler: @escaping ([String: JSONValue]?) async throws -> MCPToolResult) {
        self.toolName = toolName
        self.closure = handler
    }

    func handle(arguments: [String: JSONValue]?) async throws -> MCPToolResult {
        try await closure(arguments)
    }
}
