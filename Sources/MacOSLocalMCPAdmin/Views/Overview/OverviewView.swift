import SwiftUI

/// The Overview dashboard showing server status, stats, and recent activity.
struct OverviewView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                serverStatusSection
                statisticsSection
                recentActivitySection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Overview")
    }

    // MARK: - Server Status

    private var serverStatusSection: some View {
        GroupBox("Server") {
            HStack(spacing: 16) {
                statusIndicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.serverStatus.label)
                        .font(.headline)
                    statusDetail
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                serverControls
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var statusDetail: some View {
        switch appState.serverStatus {
        case .configured:
            Text("Ready for MCP clients")
        case .active(let pid):
            Text("PID \(pid)  \u{00B7}  Processing request")
        case .notConfigured:
            Text("Binary not found at ~/bin/macos-local-mcp")
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
            )
    }

    private var statusColor: Color {
        switch appState.serverStatus {
        case .configured:    return .green
        case .active:        return .green
        case .notConfigured: return .secondary
        }
    }

    private var serverControls: some View {
        HStack(spacing: 8) {
            if case .notConfigured = appState.serverStatus {
                Button("Run Installer") {
                    openTerminalWithInstaller()
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                appState.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func openTerminalWithInstaller() {
        // Open the project directory in Terminal so user can run install.sh
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        GroupBox("Statistics") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                StatCell(
                    label: "Total Calls",
                    value: "\(appState.activityCount)"
                )
                StatCell(
                    label: "Modules Active",
                    value: "\(appState.modules.filter(\.isEnabled).count) / \(appState.modules.count)"
                )
                StatCell(
                    label: "Permissions",
                    value: "\(appState.permissions.filter { $0.status == .authorized }.count) / \(appState.permissions.count)"
                )
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        GroupBox("Recent Activity") {
            if appState.recentActivity.isEmpty {
                Text("No activity recorded yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.recentActivity.prefix(10)) { entry in
                        ActivityRowView(entry: entry)
                        if entry.id != appState.recentActivity.prefix(10).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - StatCell

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
