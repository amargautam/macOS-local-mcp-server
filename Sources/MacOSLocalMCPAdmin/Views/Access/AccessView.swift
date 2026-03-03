import SwiftUI

/// Displays the permission status for each macOS Local MCP module.
/// Provides a shortcut to open the relevant System Settings pane.
struct AccessView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(appState.permissions) { permission in
            PermissionRowView(permission: permission)
        }
        .navigationTitle("Access")
        .toolbar {
            ToolbarItem {
                Button {
                    appState.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Re-check permissions")
            }
            ToolbarItem {
                Button("System Settings...") {
                    openPrivacySettings()
                }
                .help("Open Privacy & Security in System Settings")
            }
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - PermissionRowView

private struct PermissionRowView: View {
    let permission: ModulePermission

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                    .font(.body)
                if let note = permission.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusLabel
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: some View {
        let (imageName, color) = iconForStatus(permission.status)
        return Image(systemName: imageName)
            .foregroundStyle(color)
            .frame(width: 20)
    }

    private var statusLabel: some View {
        Text(permission.status.label)
            .font(.caption)
            .foregroundStyle(colorForStatus(permission.status))
    }

    private func iconForStatus(_ status: PermissionStatus) -> (String, Color) {
        switch status {
        case .authorized:    return ("checkmark.circle.fill", .green)
        case .denied:        return ("xmark.circle.fill", .red)
        case .notDetermined: return ("questionmark.circle", .secondary)
        case .restricted:    return ("exclamationmark.triangle.fill", .orange)
        }
    }

    private func colorForStatus(_ status: PermissionStatus) -> Color {
        switch status {
        case .authorized:    return .green
        case .denied:        return .red
        case .notDetermined: return .secondary
        case .restricted:    return .orange
        }
    }
}
