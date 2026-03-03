import SwiftUI

/// Lets the user control read/write access for each macOS Local MCP module.
/// Changes are persisted to config.json immediately.
struct ModulesView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                // Header row
                HStack {
                    Text("Module")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Read")
                        .fontWeight(.semibold)
                        .frame(width: 60)
                    Text("Write")
                        .fontWeight(.semibold)
                        .frame(width: 60)
                }
                .padding(.bottom, 4)

                ForEach($appState.modules) { $module in
                    HStack {
                        Text(module.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: Binding(
                            get: { module.readEnabled },
                            set: { newValue in
                                appState.setModuleAccess(
                                    module.name,
                                    read: newValue,
                                    write: module.writeEnabled
                                )
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 60)

                        Toggle("", isOn: Binding(
                            get: { module.writeEnabled },
                            set: { newValue in
                                appState.setModuleAccess(
                                    module.name,
                                    read: module.readEnabled,
                                    write: newValue
                                )
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 60)
                    }
                }
            } header: {
                Text("Module Access Control")
            } footer: {
                Text("Read: list, search, get operations. Write: create, update, delete, send operations.\nChanges take effect on the next server restart.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Modules")
    }
}
