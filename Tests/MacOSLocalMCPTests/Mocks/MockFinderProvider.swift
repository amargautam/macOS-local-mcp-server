import Foundation
@testable import MacOSLocalMCP

final class MockFinderProvider: FinderProviding {
    var spotlightSearchCalled = false
    var spotlightSearchContentCalled = false
    var getFileMetadataCalled = false
    var setFinderTagsCalled = false
    var listFinderTagsCalled = false
    var getTaggedFilesCalled = false

    var spotlightSearchResult: [[String: Any]] = []
    var spotlightSearchContentResult: [[String: Any]] = []
    var getFileMetadataResult: [String: Any] = [:]
    var setFinderTagsResult: [String: Any] = [:]
    var listFinderTagsResult: [[String: Any]] = []
    var getTaggedFilesResult: [[String: Any]] = []

    var spotlightSearchError: Error?
    var spotlightSearchContentError: Error?
    var getFileMetadataError: Error?
    var setFinderTagsError: Error?
    var listFinderTagsError: Error?
    var getTaggedFilesError: Error?

    var lastSearchQuery: String?
    var lastFilePath: String?
    var lastSetTags: [String]?

    func spotlightSearch(query: String, kind: String?, directory: String?, maxResults: Int?) async throws -> [[String: Any]] {
        spotlightSearchCalled = true
        lastSearchQuery = query
        if let error = spotlightSearchError { throw error }
        return spotlightSearchResult
    }

    func spotlightSearchContent(query: String, directory: String?, maxResults: Int?) async throws -> [[String: Any]] {
        spotlightSearchContentCalled = true
        if let error = spotlightSearchContentError { throw error }
        return spotlightSearchContentResult
    }

    func getFileMetadata(path: String) async throws -> [String: Any] {
        getFileMetadataCalled = true
        lastFilePath = path
        if let error = getFileMetadataError { throw error }
        return getFileMetadataResult
    }

    func setFinderTags(path: String, tags: [String]) async throws -> [String: Any] {
        setFinderTagsCalled = true
        lastFilePath = path
        lastSetTags = tags
        if let error = setFinderTagsError { throw error }
        return setFinderTagsResult
    }

    func listFinderTags() async throws -> [[String: Any]] {
        listFinderTagsCalled = true
        if let error = listFinderTagsError { throw error }
        return listFinderTagsResult
    }

    func getTaggedFiles(tag: String) async throws -> [[String: Any]] {
        getTaggedFilesCalled = true
        if let error = getTaggedFilesError { throw error }
        return getTaggedFilesResult
    }
}
