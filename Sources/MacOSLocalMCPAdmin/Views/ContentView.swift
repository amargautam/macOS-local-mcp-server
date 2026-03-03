import SwiftUI

/// The root view. Uses NavigationSplitView for a standard macOS
/// sidebar + detail layout matching System Settings and Finder conventions.
struct ContentView: View {

    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarItem? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            detailView
        }
        .navigationTitle(selection?.title ?? "macOS Local MCP Server")
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview, .none:
            OverviewView()
        case .activity:
            ActivityView()
        case .access:
            AccessView()
        case .modules:
            ModulesView()
        case .settings:
            SettingsView()
        }
    }
}
