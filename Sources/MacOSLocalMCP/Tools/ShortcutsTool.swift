import Foundation

/// Provides MCP tool handlers for the macOS Shortcuts app.
final class ShortcutsTool {

    private let provider: ShortcutsProviding

    init(provider: ShortcutsProviding) {
        self.provider = provider
    }

    /// Returns all three tool handlers: list_shortcuts, run_shortcut, get_shortcut_details.
    func createHandlers() -> [MCPToolHandler] {
        return [
            makeListShortcutsHandler(),
            makeRunShortcutHandler(),
            makeGetShortcutDetailsHandler()
        ]
    }

    // MARK: - list_shortcuts

    private func makeListShortcutsHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_shortcuts") { [weak self] _ in
            guard let self = self else {
                return .error("ShortcutsTool has been deallocated")
            }
            do {
                let shortcuts = try await self.provider.listShortcuts()
                return self.formatListResult(shortcuts)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func formatListResult(_ shortcuts: [[String: Any]]) -> MCPToolResult {
        if shortcuts.isEmpty {
            return .text("No shortcuts found.")
        }

        let lines = shortcuts.compactMap { item -> String? in
            guard let name = item["name"] as? String else { return nil }
            if let folder = item["folder"] as? String {
                return "- \(name) [\(folder)]"
            }
            return "- \(name)"
        }

        let text = "Shortcuts (\(shortcuts.count)):\n" + lines.joined(separator: "\n")
        return .text(text)
    }

    // MARK: - run_shortcut

    private func makeRunShortcutHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "run_shortcut") { [weak self] arguments in
            guard let self = self else {
                return .error("ShortcutsTool has been deallocated")
            }

            guard let args = arguments,
                  case .string(let name) = args["name"] else {
                return .error("Missing required parameter: name")
            }

            let input: String?
            if case .string(let inputValue) = args["input"] {
                input = inputValue
            } else {
                input = nil
            }

            guard case .bool(let confirmation) = args["confirmation"], confirmation else {
                return .error("Running shortcuts requires confirmation: true for safety.")
            }

            do {
                let result = try await self.provider.runShortcut(
                    name: name,
                    input: input,
                    confirmation: confirmation
                )
                return self.formatRunResult(name: name, result: result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func formatRunResult(name: String, result: [String: Any]) -> MCPToolResult {
        var lines = ["Shortcut '\(name)' ran successfully."]

        if let output = result["output"] as? String, !output.isEmpty {
            lines.append("Output: \(output)")
        }

        return .text(lines.joined(separator: "\n"))
    }

    // MARK: - get_shortcut_details

    private func makeGetShortcutDetailsHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "get_shortcut_details") { [weak self] arguments in
            guard let self = self else {
                return .error("ShortcutsTool has been deallocated")
            }

            guard let args = arguments,
                  case .string(let name) = args["name"] else {
                return .error("Missing required parameter: name")
            }

            do {
                let details = try await self.provider.getShortcutDetails(name: name)
                return self.formatDetailsResult(details)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func formatDetailsResult(_ details: [String: Any]) -> MCPToolResult {
        var lines: [String] = []

        if let name = details["name"] as? String {
            lines.append("Name: \(name)")
        }
        if let folder = details["folder"] as? String {
            lines.append("Folder: \(folder)")
        }
        if let actions = details["actions"] as? Int {
            lines.append("Actions: \(actions)")
        }
        if let available = details["available"] as? Bool {
            lines.append("Available: \(available ? "Yes" : "No")")
        }

        let text = lines.isEmpty ? "No details available." : lines.joined(separator: "\n")
        return .text(text)
    }
}
