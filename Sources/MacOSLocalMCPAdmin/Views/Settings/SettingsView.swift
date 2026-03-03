import SwiftUI

/// Settings panel for the admin app and MCP server configuration.
/// Displayed both as a detail view and as a standalone Settings scene.
struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @State private var localConfig: AppConfig = .defaults
    @State private var hasUnsavedChanges = false

    var body: some View {
        Form {
            serverSection
            loggingSection
            confirmationSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            localConfig = appState.config
        }
        .onChange(of: appState.config) { newConfig in
            if !hasUnsavedChanges {
                localConfig = newConfig
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    appState.saveConfig(localConfig)
                    hasUnsavedChanges = false
                }
                .disabled(!hasUnsavedChanges)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Revert") {
                    localConfig = appState.config
                    hasUnsavedChanges = false
                }
                .disabled(!hasUnsavedChanges)
            }
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section("Server") {
            LabeledContent("Config directory") {
                Text(configDirectoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Button("Reveal in Finder") {
                revealConfigDirectory()
            }
            .buttonStyle(.borderless)
        }
    }

    private var loggingSection: some View {
        Section("Logging") {
            Picker("Log level", selection: $localConfig.logLevel) {
                Text("Normal").tag("normal")
                Text("Verbose").tag("verbose")
                Text("Debug").tag("debug")
            }
            .onChange(of: localConfig.logLevel) { _ in hasUnsavedChanges = true }

            Stepper(
                "Max log size: \(localConfig.logMaxSizeMB) MB",
                value: $localConfig.logMaxSizeMB,
                in: 1...500,
                step: 5
            )
            .onChange(of: localConfig.logMaxSizeMB) { _ in hasUnsavedChanges = true }
        }
    }

    private var confirmationSection: some View {
        Section {
            ForEach(sortedConfirmationKeys, id: \.self) { key in
                Toggle(
                    displayName(for: key),
                    isOn: Binding(
                        get: { localConfig.confirmationRequired[key] ?? false },
                        set: { newValue in
                            localConfig.confirmationRequired[key] = newValue
                            hasUnsavedChanges = true
                        }
                    )
                )
            }
        } header: {
            Text("Require Confirmation")
        } footer: {
            Text("When enabled, Claude will ask you to approve these actions before executing them.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var configDirectoryPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.macos-local-mcp"
    }

    private var sortedConfirmationKeys: [String] {
        localConfig.confirmationRequired.keys.sorted()
    }

    private func displayName(for key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func revealConfigDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".macos-local-mcp")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
    }
}
