import Foundation

/// The operational state of the macOS Local MCP server.
///
/// The server uses a spawn-on-demand architecture — MCP clients start a fresh
/// process for each session. Status reflects whether the binary is installed
/// and ready, not whether a process is currently alive.
public enum ServerStatus: Equatable {
    /// The server binary is installed and ready for MCP clients to use.
    case configured
    /// A server process is actively handling a request right now.
    case active(pid: Int)
    /// The server binary is not installed at the expected path.
    case notConfigured
}

extension ServerStatus {
    /// A human-readable label for display in the UI.
    public var label: String {
        switch self {
        case .configured:
            return "Available"
        case .active:
            return "Active"
        case .notConfigured:
            return "Not Installed"
        }
    }

    /// Whether the server is installed and available for use.
    public var isHealthy: Bool {
        switch self {
        case .configured, .active:
            return true
        case .notConfigured:
            return false
        }
    }
}
