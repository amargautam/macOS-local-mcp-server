import SwiftUI

/// The navigation items available in the sidebar.
enum SidebarItem: String, CaseIterable, Identifiable {
    case overview
    case activity
    case access
    case modules
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview:  return "Overview"
        case .activity:  return "Activity"
        case .access:    return "Access"
        case .modules:   return "Modules"
        case .settings:  return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:  return "gauge.medium"
        case .activity:  return "list.bullet.rectangle"
        case .access:    return "lock.shield"
        case .modules:   return "switch.2"
        case .settings:  return "gearshape"
        }
    }
}

/// The sidebar navigation list for the admin app.
struct SidebarView: View {

    @Binding var selection: SidebarItem?
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.title, systemImage: item.systemImage)
                .modifier(OptionalBadge(count: badge(for: item)))
        }
        .listStyle(.sidebar)
        .navigationTitle("macOS Local MCP Server")
        .frame(minWidth: 180)
        .toolbar {
            ToolbarItem {
                Button {
                    appState.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh status")
            }
        }
    }

    private func badge(for item: SidebarItem) -> Int? {
        switch item {
        case .access:
            let denied = appState.permissions.filter { $0.status == .denied }.count
            return denied > 0 ? denied : nil
        default:
            return nil
        }
    }
}

/// ViewModifier that applies a badge only when count is non-nil.
private struct OptionalBadge: ViewModifier {
    let count: Int?
    func body(content: Content) -> some View {
        if let count {
            content.badge(count)
        } else {
            content
        }
    }
}
