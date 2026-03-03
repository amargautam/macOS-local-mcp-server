import Foundation
@testable import MacOSLocalMCP

final class MockSafariProvider: SafariProviding {

    // MARK: - Call tracking

    var listOpenTabsCalled = false
    var listReadingListCalled = false
    var searchBookmarksCalled = false
    var searchHistoryCalled = false
    var closeTabCalled = false
    var addToReadingListCalled = false
    var addBookmarkCalled = false
    var deleteBookmarkCalled = false
    var listBookmarkFoldersCalled = false
    var createBookmarkFolderCalled = false
    var findDuplicateTabsCalled = false
    var closeTabsMatchingCalled = false
    var getTabContentCalled = false
    var newTabCalled = false
    var reloadTabCalled = false

    // MARK: - Results

    var listOpenTabsResult: [[String: Any]] = []
    var listReadingListResult: [[String: Any]] = []
    var searchBookmarksResult: [[String: Any]] = []
    var searchHistoryResult: [[String: Any]] = []
    var closeTabResult: [String: Any] = [:]
    var addToReadingListResult: [String: Any] = [:]
    var addBookmarkResult: [String: Any] = [:]
    var deleteBookmarkResult: [String: Any] = [:]
    var listBookmarkFoldersResult: [[String: Any]] = []
    var createBookmarkFolderResult: [String: Any] = [:]
    var findDuplicateTabsResult: [[String: Any]] = []
    var closeTabsMatchingResult: [String: Any] = [:]
    var getTabContentResult: [String: Any] = [:]
    var newTabResult: [String: Any] = [:]
    var reloadTabResult: [String: Any] = [:]

    // MARK: - Errors

    var listOpenTabsError: Error?
    var listReadingListError: Error?
    var searchBookmarksError: Error?
    var searchHistoryError: Error?
    var closeTabError: Error?
    var addToReadingListError: Error?
    var addBookmarkError: Error?
    var deleteBookmarkError: Error?
    var listBookmarkFoldersError: Error?
    var createBookmarkFolderError: Error?
    var findDuplicateTabsError: Error?
    var closeTabsMatchingError: Error?
    var getTabContentError: Error?
    var newTabError: Error?
    var reloadTabError: Error?

    // MARK: - Protocol conformance (original 5)

    func listOpenTabs() async throws -> [[String: Any]] {
        listOpenTabsCalled = true
        if let error = listOpenTabsError { throw error }
        return listOpenTabsResult
    }

    func listReadingList() async throws -> [[String: Any]] {
        listReadingListCalled = true
        if let error = listReadingListError { throw error }
        return listReadingListResult
    }

    func searchBookmarks(query: String) async throws -> [[String: Any]] {
        searchBookmarksCalled = true
        if let error = searchBookmarksError { throw error }
        return searchBookmarksResult
    }

    func searchHistory(query: String, daysBack: Int?) async throws -> [[String: Any]] {
        searchHistoryCalled = true
        if let error = searchHistoryError { throw error }
        return searchHistoryResult
    }

    func closeTab(index: Int?, url: String?, confirmation: Bool) async throws -> [String: Any] {
        closeTabCalled = true
        if let error = closeTabError { throw error }
        return closeTabResult
    }

    // MARK: - Protocol conformance (new 10)

    func addToReadingList(url: String, title: String?) async throws -> [String: Any] {
        addToReadingListCalled = true
        if let error = addToReadingListError { throw error }
        return addToReadingListResult
    }

    func addBookmark(url: String, title: String, folderName: String?) async throws -> [String: Any] {
        addBookmarkCalled = true
        if let error = addBookmarkError { throw error }
        return addBookmarkResult
    }

    func deleteBookmark(title: String?, url: String?, confirmation: Bool) async throws -> [String: Any] {
        deleteBookmarkCalled = true
        if let error = deleteBookmarkError { throw error }
        return deleteBookmarkResult
    }

    func listBookmarkFolders() async throws -> [[String: Any]] {
        listBookmarkFoldersCalled = true
        if let error = listBookmarkFoldersError { throw error }
        return listBookmarkFoldersResult
    }

    func createBookmarkFolder(name: String) async throws -> [String: Any] {
        createBookmarkFolderCalled = true
        if let error = createBookmarkFolderError { throw error }
        return createBookmarkFolderResult
    }

    func findDuplicateTabs() async throws -> [[String: Any]] {
        findDuplicateTabsCalled = true
        if let error = findDuplicateTabsError { throw error }
        return findDuplicateTabsResult
    }

    func closeTabsMatching(pattern: String, confirmation: Bool) async throws -> [String: Any] {
        closeTabsMatchingCalled = true
        if let error = closeTabsMatchingError { throw error }
        return closeTabsMatchingResult
    }

    func getTabContent(index: Int?, url: String?) async throws -> [String: Any] {
        getTabContentCalled = true
        if let error = getTabContentError { throw error }
        return getTabContentResult
    }

    func newTab(url: String) async throws -> [String: Any] {
        newTabCalled = true
        if let error = newTabError { throw error }
        return newTabResult
    }

    func reloadTab(index: Int?, url: String?) async throws -> [String: Any] {
        reloadTabCalled = true
        if let error = reloadTabError { throw error }
        return reloadTabResult
    }
}
