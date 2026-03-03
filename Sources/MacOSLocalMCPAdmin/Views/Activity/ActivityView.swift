import SwiftUI

/// Displays the full activity log with filtering by tool name and status.
struct ActivityView: View {

    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var sortOrder: [KeyPathComparator<ActivityEntry>] = [
        KeyPathComparator(\.ts, order: .reverse)
    ]

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case success = "Success"
        case error = "Error"
        case confirmation = "Confirmation"
    }

    private var filteredEntries: [ActivityEntry] {
        appState.recentActivity.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.tool.localizedCaseInsensitiveContains(searchText)
                || (entry.error ?? "").localizedCaseInsensitiveContains(searchText)
            let matchesStatus: Bool
            switch statusFilter {
            case .all:           matchesStatus = true
            case .success:       matchesStatus = entry.status == "success"
            case .error:         matchesStatus = entry.status == "error"
            case .confirmation:  matchesStatus = entry.status == "confirmation_required"
            }
            return matchesSearch && matchesStatus
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryTable
            }
        }
        .navigationTitle("Activity")
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            Text("\(filteredEntries.count) entries")
                .foregroundStyle(.secondary)
                .font(.caption)

            Button {
                appState.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Table

    private var entryTable: some View {
        Table(filteredEntries, sortOrder: $sortOrder) {
            TableColumn("Time", value: \.ts) { entry in
                Text(entry.ts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 200)

            TableColumn("Tool", value: \.tool) { entry in
                Text(entry.tool)
                    .font(.body)
                    .lineLimit(1)
            }
            .width(min: 140, ideal: 180)

            TableColumn("Status") { entry in
                StatusBadge(status: entry.status)
            }
            .width(80)

            TableColumn("Duration") { entry in
                Text("\(entry.duration_ms)ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(70)

            TableColumn("Results") { entry in
                if let count = entry.result_count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .width(60)

            TableColumn("Error") { entry in
                if let error = entry.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    EmptyView()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search tools or errors")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No activity recorded." : "No matching entries.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var label: String {
        switch status {
        case "success":               return "Success"
        case "error":                 return "Error"
        case "confirmation_required": return "Confirm"
        default:                      return status
        }
    }

    private var color: Color {
        switch status {
        case "success": return .green
        case "error":   return .red
        default:        return .orange
        }
    }
}

// MARK: - ActivityRowView (used by OverviewView)

struct ActivityRowView: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: entry.status)
                .frame(width: 64, alignment: .leading)

            Text(entry.tool)
                .font(.body)
                .lineLimit(1)

            Spacer()

            Text("\(entry.duration_ms)ms")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}
