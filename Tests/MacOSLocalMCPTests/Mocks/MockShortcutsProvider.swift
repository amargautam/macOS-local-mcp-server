import Foundation
@testable import MacOSLocalMCP

final class MockShortcutsProvider: ShortcutsProviding {
    var listShortcutsCalled = false
    var runShortcutCalled = false
    var getShortcutDetailsCalled = false

    var listShortcutsResult: [[String: Any]] = []
    var runShortcutResult: [String: Any] = [:]
    var getShortcutDetailsResult: [String: Any] = [:]

    var listShortcutsError: Error?
    var runShortcutError: Error?
    var getShortcutDetailsError: Error?

    var lastRunName: String?
    var lastRunInput: String?

    func listShortcuts() async throws -> [[String: Any]] {
        listShortcutsCalled = true
        if let error = listShortcutsError { throw error }
        return listShortcutsResult
    }

    func runShortcut(name: String, input: String?, confirmation: Bool) async throws -> [String: Any] {
        runShortcutCalled = true
        lastRunName = name
        lastRunInput = input
        if let error = runShortcutError { throw error }
        return runShortcutResult
    }

    func getShortcutDetails(name: String) async throws -> [String: Any] {
        getShortcutDetailsCalled = true
        if let error = getShortcutDetailsError { throw error }
        return getShortcutDetailsResult
    }
}
