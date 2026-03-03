import Foundation
@testable import MacOSLocalMCP

/// Shared mock ScriptExecuting for testing AppleScript bridges without executing real scripts.
final class MockScriptExecutor: ScriptExecuting {
    var executeCalled = false
    var lastScript: String?
    var scripts: [String] = []
    var resultToReturn: String = ""
    var errorToThrow: Error?

    func executeScript(_ source: String) throws -> String {
        executeCalled = true
        lastScript = source
        scripts.append(source)
        if let error = errorToThrow { throw error }
        return resultToReturn
    }
}
