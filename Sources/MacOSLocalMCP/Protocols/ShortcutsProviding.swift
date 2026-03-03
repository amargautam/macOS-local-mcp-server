import Foundation

/// Protocol for interacting with macOS Shortcuts app.
protocol ShortcutsProviding {
    func listShortcuts() async throws -> [[String: Any]]
    func runShortcut(name: String, input: String?, confirmation: Bool) async throws -> [String: Any]
    func getShortcutDetails(name: String) async throws -> [String: Any]
}
