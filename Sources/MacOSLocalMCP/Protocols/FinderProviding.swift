import Foundation

/// Protocol for interacting with macOS Finder and Spotlight.
protocol FinderProviding {
    func spotlightSearch(query: String, kind: String?, directory: String?, maxResults: Int?) async throws -> [[String: Any]]
    func spotlightSearchContent(query: String, directory: String?, maxResults: Int?) async throws -> [[String: Any]]
    func getFileMetadata(path: String) async throws -> [String: Any]
    func setFinderTags(path: String, tags: [String]) async throws -> [String: Any]
    func listFinderTags() async throws -> [[String: Any]]
    func getTaggedFiles(tag: String) async throws -> [[String: Any]]
}
