import Foundation

/// Creates MCPToolHandler instances for all Safari tools.
final class SafariTool {

    private let provider: SafariProviding

    init(provider: SafariProviding) {
        self.provider = provider
    }

    /// Returns one MCPToolHandler per Safari tool (15 total).
    func createHandlers() -> [MCPToolHandler] {
        return [
            makeListOpenTabsHandler(),
            makeListReadingListHandler(),
            makeSearchBookmarksHandler(),
            makeSearchHistoryHandler(),
            makeCloseTabHandler(),
            makeAddToReadingListHandler(),
            makeAddBookmarkHandler(),
            makeDeleteBookmarkHandler(),
            makeListBookmarkFoldersHandler(),
            makeCreateBookmarkFolderHandler(),
            makeFindDuplicateTabsHandler(),
            makeCloseTabsMatchingHandler(),
            makeGetTabContentHandler(),
            makeNewTabHandler(),
            makeReloadTabHandler(),
        ]
    }

    // MARK: - Handler Factories (original 5)

    private func makeListOpenTabsHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "list_open_tabs") { _ in
            do {
                let tabs = try await p.listOpenTabs()
                return .text(formatTabList(tabs))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeListReadingListHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "list_reading_list") { _ in
            do {
                let items = try await p.listReadingList()
                return .text(formatReadingList(items))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeSearchBookmarksHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "search_bookmarks") { args in
            guard let query = args?["query"]?.stringValue else {
                return .error("Missing required parameter: query")
            }
            do {
                let results = try await p.searchBookmarks(query: query)
                return .text(formatBookmarkList(results))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeSearchHistoryHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "search_history") { args in
            guard let query = args?["query"]?.stringValue else {
                return .error("Missing required parameter: query")
            }
            let daysBack = args?["days_back"]?.intValue
            do {
                let results = try await p.searchHistory(query: query, daysBack: daysBack)
                return .text(formatHistoryList(results))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeCloseTabHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "close_tab") { args in
            guard let confirmation = args?["confirmation"]?.boolValue, confirmation else {
                return .error("close_tab requires confirmation: true to proceed")
            }
            let index = args?["index"]?.intValue
            let url = args?["url"]?.stringValue
            do {
                let result = try await p.closeTab(index: index, url: url, confirmation: true)
                return .text(formatCloseTabResult(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Handler Factories (new 10)

    private func makeAddToReadingListHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "add_to_reading_list") { args in
            guard let url = args?["url"]?.stringValue else {
                return .error("Missing required parameter: url")
            }
            let title = args?["title"]?.stringValue
            do {
                let result = try await p.addToReadingList(url: url, title: title)
                return .text(formatSimpleResult(result, defaultMessage: "Added to reading list."))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeAddBookmarkHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "add_bookmark") { args in
            guard let url = args?["url"]?.stringValue else {
                return .error("Missing required parameter: url")
            }
            guard let title = args?["title"]?.stringValue else {
                return .error("Missing required parameter: title")
            }
            let folderName = args?["folder_name"]?.stringValue
            do {
                let result = try await p.addBookmark(url: url, title: title, folderName: folderName)
                return .text(formatSimpleResult(result, defaultMessage: "Bookmark added."))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeDeleteBookmarkHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "delete_bookmark") { args in
            guard let confirmation = args?["confirmation"]?.boolValue, confirmation else {
                return .error("delete_bookmark requires confirmation: true to proceed")
            }
            let title = args?["title"]?.stringValue
            let url = args?["url"]?.stringValue
            guard title != nil || url != nil else {
                return .error("At least one of title or url must be provided")
            }
            do {
                let result = try await p.deleteBookmark(title: title, url: url, confirmation: true)
                return .text(formatSimpleResult(result, defaultMessage: "Bookmark deleted."))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeListBookmarkFoldersHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "list_bookmark_folders") { _ in
            do {
                let folders = try await p.listBookmarkFolders()
                return .text(formatBookmarkFolderList(folders))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeCreateBookmarkFolderHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "create_bookmark_folder") { args in
            guard let name = args?["name"]?.stringValue else {
                return .error("Missing required parameter: name")
            }
            do {
                let result = try await p.createBookmarkFolder(name: name)
                return .text(formatCreateFolderResult(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeFindDuplicateTabsHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "find_duplicate_tabs") { _ in
            do {
                let duplicates = try await p.findDuplicateTabs()
                return .text(formatDuplicateTabList(duplicates))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeCloseTabsMatchingHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "close_tabs_matching") { args in
            guard let confirmation = args?["confirmation"]?.boolValue, confirmation else {
                return .error("close_tabs_matching requires confirmation: true to proceed")
            }
            guard let pattern = args?["pattern"]?.stringValue else {
                return .error("Missing required parameter: pattern")
            }
            do {
                let result = try await p.closeTabsMatching(pattern: pattern, confirmation: true)
                return .text(formatCloseTabsMatchingResult(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeGetTabContentHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "get_tab_content") { args in
            let index = args?["index"]?.intValue
            let url = args?["url"]?.stringValue
            guard index != nil || url != nil else {
                return .error("At least one of index or url must be provided")
            }
            do {
                let result = try await p.getTabContent(index: index, url: url)
                return .text(formatTabContentResult(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeNewTabHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "new_tab") { args in
            guard let url = args?["url"]?.stringValue else {
                return .error("Missing required parameter: url")
            }
            do {
                let result = try await p.newTab(url: url)
                return .text(formatNewTabResult(result))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func makeReloadTabHandler() -> MCPToolHandler {
        let p = provider
        return ClosureToolHandler(toolName: "reload_tab") { args in
            let index = args?["index"]?.intValue
            let url = args?["url"]?.stringValue
            guard index != nil || url != nil else {
                return .error("At least one of index or url must be provided")
            }
            do {
                let result = try await p.reloadTab(index: index, url: url)
                return .text(formatSimpleResult(result, defaultMessage: "Tab reloaded."))
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

}

// MARK: - Formatting Helpers

private func formatTabList(_ tabs: [[String: Any]]) -> String {
    if tabs.isEmpty {
        return "No open tabs found."
    }
    var lines: [String] = ["Open tabs (\(tabs.count)):"]
    for tab in tabs {
        let title = tab["title"] as? String ?? "(no title)"
        let url = tab["url"] as? String ?? ""
        let win = tab["windowIndex"] as? Int ?? 0
        let idx = tab["tabIndex"] as? Int ?? 0
        lines.append("  [\(win):\(idx)] \(title)\n        \(url)")
    }
    return lines.joined(separator: "\n")
}

private func formatReadingList(_ items: [[String: Any]]) -> String {
    if items.isEmpty {
        return "Reading list is empty."
    }
    var lines: [String] = ["Reading list (\(items.count) items):"]
    for item in items {
        let title = item["title"] as? String ?? "(no title)"
        let url = item["url"] as? String ?? ""
        lines.append("  - \(title)\n    \(url)")
    }
    return lines.joined(separator: "\n")
}

private func formatBookmarkList(_ bookmarks: [[String: Any]]) -> String {
    if bookmarks.isEmpty {
        return "No bookmarks found matching your query."
    }
    var lines: [String] = ["Found \(bookmarks.count) bookmark(s):"]
    for bm in bookmarks {
        let title = bm["title"] as? String ?? "(no title)"
        let url = bm["url"] as? String ?? ""
        lines.append("  - \(title)\n    \(url)")
    }
    return lines.joined(separator: "\n")
}

private func formatHistoryList(_ items: [[String: Any]]) -> String {
    if items.isEmpty {
        return "No history entries found matching your query."
    }
    var lines: [String] = ["Found \(items.count) history entry/entries:"]
    for item in items {
        let title = item["title"] as? String ?? "(no title)"
        let url = item["url"] as? String ?? ""
        let date = item["visitDate"] as? String ?? ""
        let datePart = date.isEmpty ? "" : " [\(date)]"
        lines.append("  - \(title)\(datePart)\n    \(url)")
    }
    return lines.joined(separator: "\n")
}

private func formatCloseTabResult(_ result: [String: Any]) -> String {
    let success = result["success"] as? Bool ?? false
    let message = result["message"] as? String ?? (success ? "Tab closed." : "Failed to close tab.")
    return message
}

private func formatSimpleResult(_ result: [String: Any], defaultMessage: String) -> String {
    if let message = result["message"] as? String {
        return message
    }
    let success = result["success"] as? Bool ?? true
    return success ? defaultMessage : "Operation failed."
}

private func formatBookmarkFolderList(_ folders: [[String: Any]]) -> String {
    if folders.isEmpty {
        return "No bookmark folders found."
    }
    var lines: [String] = ["Bookmark folders (\(folders.count)):"]
    for folder in folders {
        let name = folder["name"] as? String ?? "(unnamed)"
        lines.append("  - \(name)")
    }
    return lines.joined(separator: "\n")
}

private func formatCreateFolderResult(_ result: [String: Any]) -> String {
    if let name = result["name"] as? String {
        return "Bookmark folder created: \(name)"
    }
    let success = result["success"] as? Bool ?? false
    let message = result["message"] as? String ?? (success ? "Folder created." : "Failed to create folder.")
    return message
}

private func formatDuplicateTabList(_ duplicates: [[String: Any]]) -> String {
    if duplicates.isEmpty {
        return "No duplicate tabs found."
    }
    var lines: [String] = ["Found \(duplicates.count) URL(s) with duplicate tabs:"]
    for dup in duplicates {
        let url = dup["url"] as? String ?? ""
        let count = dup["count"] as? Int ?? 0
        lines.append("  - \(url) (\(count) tabs)")
    }
    return lines.joined(separator: "\n")
}

private func formatCloseTabsMatchingResult(_ result: [String: Any]) -> String {
    let message = result["message"] as? String
    let count = result["closedCount"] as? Int
    if let msg = message {
        return msg
    }
    if let n = count {
        return "Closed \(n) tab(s)."
    }
    let success = result["success"] as? Bool ?? false
    return success ? "Tabs closed." : "Failed to close tabs."
}

private func formatTabContentResult(_ result: [String: Any]) -> String {
    if let success = result["success"] as? Bool, !success {
        let message = result["message"] as? String ?? "Failed to get tab content."
        return message
    }
    let title = result["title"] as? String ?? "(no title)"
    let url = result["url"] as? String ?? ""
    let content = result["content"] as? String ?? ""
    var lines: [String] = []
    lines.append("Title: \(title)")
    if !url.isEmpty {
        lines.append("URL: \(url)")
    }
    if !content.isEmpty {
        lines.append("")
        lines.append(content)
    }
    return lines.joined(separator: "\n")
}

private func formatNewTabResult(_ result: [String: Any]) -> String {
    if let url = result["url"] as? String {
        return "Opened new tab: \(url)"
    }
    let success = result["success"] as? Bool ?? false
    let message = result["message"] as? String ?? (success ? "New tab opened." : "Failed to open new tab.")
    return message
}

// MARK: - JSONValue helpers

private extension JSONValue {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
