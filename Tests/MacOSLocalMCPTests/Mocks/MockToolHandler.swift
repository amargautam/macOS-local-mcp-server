import Foundation
@testable import MacOSLocalMCP

/// A mock tool handler for testing tool routing and execution.
final class MockToolHandler: MCPToolHandler {
    let toolName: String
    var handleCalled = false
    var lastArguments: [String: JSONValue]?
    var resultToReturn: MCPToolResult = .text("mock result")
    var errorToThrow: Error?

    init(toolName: String) {
        self.toolName = toolName
    }

    func handle(arguments: [String: JSONValue]?) async throws -> MCPToolResult {
        handleCalled = true
        lastArguments = arguments
        if let error = errorToThrow { throw error }
        return resultToReturn
    }
}
