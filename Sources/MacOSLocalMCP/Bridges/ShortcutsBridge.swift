import Foundation

// MARK: - Shortcuts Errors

/// Errors that can be thrown by Shortcuts operations.
enum ShortcutsError: Error, LocalizedError {
    case commandFailed(String)
    case shortcutNotFound(String)
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Shortcuts command failed: \(message)"
        case .shortcutNotFound(let name):
            return "Shortcut not found: \(name)"
        case .invalidOutput(let detail):
            return "Invalid output from shortcuts CLI: \(detail)"
        }
    }
}

// MARK: - ShortcutsBridge

/// Implements ShortcutsProviding using the macOS `shortcuts` CLI tool.
final class ShortcutsBridge: ShortcutsProviding {

    private let shell: ShellCommandExecuting
    private let shortcutsPath = "/usr/bin/shortcuts"

    init(shell: ShellCommandExecuting = ProcessShellExecutor()) {
        self.shell = shell
    }

    // MARK: - listShortcuts

    func listShortcuts() async throws -> [[String: Any]] {
        let output: String
        do {
            output = try shell.execute(command: shortcutsPath, arguments: ["list"])
        } catch {
            throw ShortcutsError.commandFailed(error.localizedDescription)
        }

        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.map { name in
            ["name": name]
        }
    }

    // MARK: - runShortcut

    func runShortcut(name: String, input: String?, confirmation: Bool) async throws -> [String: Any] {
        guard confirmation else {
            throw ShortcutsError.commandFailed("Running shortcuts requires confirmation.")
        }

        var arguments = ["run", name]
        var tempURL: URL?

        if let input = input, !input.isEmpty {
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("shortcuts-input-\(UUID().uuidString).txt")
            try input.write(to: url, atomically: true, encoding: .utf8)
            arguments += ["--input-path", url.path]
            tempURL = url
        }

        defer {
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let output: String
        do {
            output = try shell.execute(command: shortcutsPath, arguments: arguments)
        } catch {
            throw ShortcutsError.commandFailed(error.localizedDescription)
        }

        return [
            "name": name,
            "output": output.trimmingCharacters(in: .whitespacesAndNewlines),
            "success": true
        ]
    }

    // MARK: - getShortcutDetails

    func getShortcutDetails(name: String) async throws -> [String: Any] {
        let output: String
        do {
            output = try shell.execute(command: shortcutsPath, arguments: ["list"])
        } catch {
            throw ShortcutsError.commandFailed(error.localizedDescription)
        }

        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.contains(name) else {
            throw ShortcutsError.shortcutNotFound(name)
        }

        return [
            "name": name,
            "available": true
        ]
    }
}
