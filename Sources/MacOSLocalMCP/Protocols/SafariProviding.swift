import Foundation

/// Protocol for interacting with the macOS Safari browser via AppleScript.
protocol SafariProviding {
    func listOpenTabs() async throws -> [[String: Any]]
    func listReadingList() async throws -> [[String: Any]]
    func searchBookmarks(query: String) async throws -> [[String: Any]]
    func searchHistory(query: String, daysBack: Int?) async throws -> [[String: Any]]
    func closeTab(index: Int?, url: String?, confirmation: Bool) async throws -> [String: Any]

    // New tools
    func addToReadingList(url: String, title: String?) async throws -> [String: Any]
    func addBookmark(url: String, title: String, folderName: String?) async throws -> [String: Any]
    func deleteBookmark(title: String?, url: String?, confirmation: Bool) async throws -> [String: Any]
    func listBookmarkFolders() async throws -> [[String: Any]]
    func createBookmarkFolder(name: String) async throws -> [String: Any]
    func findDuplicateTabs() async throws -> [[String: Any]]
    func closeTabsMatching(pattern: String, confirmation: Bool) async throws -> [String: Any]
    func getTabContent(index: Int?, url: String?) async throws -> [String: Any]
    func newTab(url: String) async throws -> [String: Any]
    func reloadTab(index: Int?, url: String?) async throws -> [String: Any]
}
