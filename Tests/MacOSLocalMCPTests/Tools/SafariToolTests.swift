import XCTest
@testable import MacOSLocalMCP

// MARK: - SafariToolTests

final class SafariToolTests: XCTestCase {

    var provider: MockSafariProvider!
    var handlers: [MCPToolHandler]!
    var handlerMap: [String: MCPToolHandler]!

    override func setUp() {
        super.setUp()
        provider = MockSafariProvider()
        let tool = SafariTool(provider: provider)
        handlers = tool.createHandlers()
        handlerMap = Dictionary(uniqueKeysWithValues: handlers.map { ($0.toolName, $0) })
    }

    // MARK: - Handler Registration

    func testCreateHandlersReturnsFifteenHandlers() {
        XCTAssertEqual(handlers.count, 15)
    }

    func testCreateHandlersRegistersAllExpectedToolNames() {
        let expectedNames: Set<String> = [
            "list_open_tabs",
            "list_reading_list",
            "search_bookmarks",
            "search_history",
            "close_tab",
            "add_to_reading_list",
            "add_bookmark",
            "delete_bookmark",
            "list_bookmark_folders",
            "create_bookmark_folder",
            "find_duplicate_tabs",
            "close_tabs_matching",
            "get_tab_content",
            "new_tab",
            "reload_tab",
        ]
        let actualNames = Set(handlers.map { $0.toolName })
        XCTAssertEqual(actualNames, expectedNames)
    }

    func testEachHandlerHasUniqueName() {
        let names = handlers.map { $0.toolName }
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count)
    }

    // MARK: - list_open_tabs

    func testListOpenTabsCallsProvider() async throws {
        provider.listOpenTabsResult = [
            ["title": "Apple", "url": "https://apple.com", "windowIndex": 1, "tabIndex": 1],
            ["title": "GitHub", "url": "https://github.com", "windowIndex": 1, "tabIndex": 2],
        ]
        let handler = try XCTUnwrap(handlerMap["list_open_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listOpenTabsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Apple"))
        XCTAssertTrue(text.contains("https://apple.com"))
    }

    func testListOpenTabsReturnsEmptyMessage() async throws {
        provider.listOpenTabsResult = []
        let handler = try XCTUnwrap(handlerMap["list_open_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testListOpenTabsPropagatesError() async throws {
        provider.listOpenTabsError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["list_open_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - list_reading_list

    func testListReadingListCallsProvider() async throws {
        provider.listReadingListResult = [
            ["title": "Swift Docs", "url": "https://swift.org/docs"],
            ["title": "SE-0296", "url": "https://github.com/apple/swift-evolution"],
        ]
        let handler = try XCTUnwrap(handlerMap["list_reading_list"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listReadingListCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Swift Docs"))
    }

    func testListReadingListReturnsEmptyMessage() async throws {
        provider.listReadingListResult = []
        let handler = try XCTUnwrap(handlerMap["list_reading_list"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testListReadingListPropagatesError() async throws {
        provider.listReadingListError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["list_reading_list"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - search_bookmarks

    func testSearchBookmarksCallsProviderWithQuery() async throws {
        provider.searchBookmarksResult = [
            ["title": "Apple Developer", "url": "https://developer.apple.com"],
        ]
        let handler = try XCTUnwrap(handlerMap["search_bookmarks"])
        let args: [String: JSONValue] = ["query": .string("apple")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.searchBookmarksCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Apple Developer"))
    }

    func testSearchBookmarksMissingQueryReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["search_bookmarks"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.searchBookmarksCalled)
    }

    func testSearchBookmarksEmptyResultReturnsMessage() async throws {
        provider.searchBookmarksResult = []
        let handler = try XCTUnwrap(handlerMap["search_bookmarks"])
        let args: [String: JSONValue] = ["query": .string("xyz123")]
        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testSearchBookmarksPropagatesError() async throws {
        provider.searchBookmarksError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["search_bookmarks"])
        let args: [String: JSONValue] = ["query": .string("apple")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - search_history

    func testSearchHistoryCallsProviderWithQueryAndDefaultDays() async throws {
        provider.searchHistoryResult = [
            ["title": "GitHub", "url": "https://github.com", "visitDate": "2026-03-01"],
        ]
        let handler = try XCTUnwrap(handlerMap["search_history"])
        let args: [String: JSONValue] = ["query": .string("github")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.searchHistoryCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("GitHub"))
    }

    func testSearchHistoryCallsProviderWithExplicitDaysBack() async throws {
        provider.searchHistoryResult = []
        let handler = try XCTUnwrap(handlerMap["search_history"])
        let args: [String: JSONValue] = ["query": .string("test"), "days_back": .int(14)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.searchHistoryCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testSearchHistoryMissingQueryReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["search_history"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.searchHistoryCalled)
    }

    func testSearchHistoryPropagatesError() async throws {
        provider.searchHistoryError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["search_history"])
        let args: [String: JSONValue] = ["query": .string("github")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - close_tab

    func testCloseTabByIndexCallsProvider() async throws {
        provider.closeTabResult = ["success": true, "message": "Tab closed"]
        let handler = try XCTUnwrap(handlerMap["close_tab"])
        let args: [String: JSONValue] = [
            "index": .int(2),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.closeTabCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testCloseTabByURLCallsProvider() async throws {
        provider.closeTabResult = ["success": true, "message": "Tab closed"]
        let handler = try XCTUnwrap(handlerMap["close_tab"])
        let args: [String: JSONValue] = [
            "url": .string("https://github.com"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.closeTabCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testCloseTabWithoutConfirmationReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["close_tab"])
        let args: [String: JSONValue] = [
            "index": .int(1),
            "confirmation": .bool(false),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.closeTabCalled)
    }

    func testCloseTabMissingConfirmationReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["close_tab"])
        let args: [String: JSONValue] = ["index": .int(1)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.closeTabCalled)
    }

    func testCloseTabPropagatesError() async throws {
        provider.closeTabError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["close_tab"])
        let args: [String: JSONValue] = [
            "index": .int(1),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - add_to_reading_list

    func testAddToReadingListCallsProviderWithURL() async throws {
        provider.addToReadingListResult = ["success": true, "message": "Added to reading list"]
        let handler = try XCTUnwrap(handlerMap["add_to_reading_list"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.addToReadingListCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testAddToReadingListCallsProviderWithURLAndTitle() async throws {
        provider.addToReadingListResult = ["success": true, "message": "Added to reading list"]
        let handler = try XCTUnwrap(handlerMap["add_to_reading_list"])
        let args: [String: JSONValue] = [
            "url": .string("https://example.com"),
            "title": .string("Example Page"),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.addToReadingListCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testAddToReadingListMissingURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["add_to_reading_list"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.addToReadingListCalled)
    }

    func testAddToReadingListPropagatesError() async throws {
        provider.addToReadingListError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["add_to_reading_list"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - add_bookmark

    func testAddBookmarkCallsProviderWithURLAndTitle() async throws {
        provider.addBookmarkResult = ["success": true, "message": "Bookmark added"]
        let handler = try XCTUnwrap(handlerMap["add_bookmark"])
        let args: [String: JSONValue] = [
            "url": .string("https://example.com"),
            "title": .string("Example"),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.addBookmarkCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testAddBookmarkCallsProviderWithFolderName() async throws {
        provider.addBookmarkResult = ["success": true, "message": "Bookmark added"]
        let handler = try XCTUnwrap(handlerMap["add_bookmark"])
        let args: [String: JSONValue] = [
            "url": .string("https://example.com"),
            "title": .string("Example"),
            "folder_name": .string("Work"),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.addBookmarkCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testAddBookmarkMissingURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["add_bookmark"])
        let args: [String: JSONValue] = ["title": .string("Example")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.addBookmarkCalled)
    }

    func testAddBookmarkMissingTitleReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["add_bookmark"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.addBookmarkCalled)
    }

    func testAddBookmarkPropagatesError() async throws {
        provider.addBookmarkError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["add_bookmark"])
        let args: [String: JSONValue] = [
            "url": .string("https://example.com"),
            "title": .string("Example"),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - delete_bookmark

    func testDeleteBookmarkByTitleRequiresConfirmation() async throws {
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = [
            "title": .string("Example"),
            "confirmation": .bool(false),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.deleteBookmarkCalled)
    }

    func testDeleteBookmarkMissingConfirmationReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = ["title": .string("Example")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.deleteBookmarkCalled)
    }

    func testDeleteBookmarkMissingTitleAndURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = ["confirmation": .bool(true)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.deleteBookmarkCalled)
    }

    func testDeleteBookmarkByTitleCallsProvider() async throws {
        provider.deleteBookmarkResult = ["success": true, "message": "Bookmark deleted"]
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = [
            "title": .string("Example"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.deleteBookmarkCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testDeleteBookmarkByURLCallsProvider() async throws {
        provider.deleteBookmarkResult = ["success": true, "message": "Bookmark deleted"]
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = [
            "url": .string("https://example.com"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.deleteBookmarkCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testDeleteBookmarkPropagatesError() async throws {
        provider.deleteBookmarkError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["delete_bookmark"])
        let args: [String: JSONValue] = [
            "title": .string("Example"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - list_bookmark_folders

    func testListBookmarkFoldersCallsProvider() async throws {
        provider.listBookmarkFoldersResult = [
            ["name": "Favourites"],
            ["name": "Work"],
        ]
        let handler = try XCTUnwrap(handlerMap["list_bookmark_folders"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listBookmarkFoldersCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Favourites"))
    }

    func testListBookmarkFoldersReturnsEmptyMessage() async throws {
        provider.listBookmarkFoldersResult = []
        let handler = try XCTUnwrap(handlerMap["list_bookmark_folders"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testListBookmarkFoldersPropagatesError() async throws {
        provider.listBookmarkFoldersError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["list_bookmark_folders"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - create_bookmark_folder

    func testCreateBookmarkFolderCallsProviderWithName() async throws {
        provider.createBookmarkFolderResult = ["success": true, "name": "NewFolder"]
        let handler = try XCTUnwrap(handlerMap["create_bookmark_folder"])
        let args: [String: JSONValue] = ["name": .string("NewFolder")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.createBookmarkFolderCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testCreateBookmarkFolderMissingNameReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["create_bookmark_folder"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.createBookmarkFolderCalled)
    }

    func testCreateBookmarkFolderPropagatesError() async throws {
        provider.createBookmarkFolderError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["create_bookmark_folder"])
        let args: [String: JSONValue] = ["name": .string("NewFolder")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - find_duplicate_tabs

    func testFindDuplicateTabsCallsProvider() async throws {
        provider.findDuplicateTabsResult = [
            ["url": "https://example.com", "count": 2, "tabs": []],
        ]
        let handler = try XCTUnwrap(handlerMap["find_duplicate_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.findDuplicateTabsCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("example.com"))
    }

    func testFindDuplicateTabsReturnsNoDuplicatesMessage() async throws {
        provider.findDuplicateTabsResult = []
        let handler = try XCTUnwrap(handlerMap["find_duplicate_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testFindDuplicateTabsPropagatesError() async throws {
        provider.findDuplicateTabsError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["find_duplicate_tabs"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - close_tabs_matching

    func testCloseTabsMatchingRequiresConfirmation() async throws {
        let handler = try XCTUnwrap(handlerMap["close_tabs_matching"])
        let args: [String: JSONValue] = [
            "pattern": .string("example.com"),
            "confirmation": .bool(false),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.closeTabsMatchingCalled)
    }

    func testCloseTabsMatchingMissingPatternReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["close_tabs_matching"])
        let args: [String: JSONValue] = ["confirmation": .bool(true)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.closeTabsMatchingCalled)
    }

    func testCloseTabsMatchingCallsProvider() async throws {
        provider.closeTabsMatchingResult = ["success": true, "closedCount": 3, "message": "Closed 3 tabs"]
        let handler = try XCTUnwrap(handlerMap["close_tabs_matching"])
        let args: [String: JSONValue] = [
            "pattern": .string("example.com"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.closeTabsMatchingCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testCloseTabsMatchingPropagatesError() async throws {
        provider.closeTabsMatchingError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["close_tabs_matching"])
        let args: [String: JSONValue] = [
            "pattern": .string("example.com"),
            "confirmation": .bool(true),
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - get_tab_content

    func testGetTabContentByIndexCallsProvider() async throws {
        provider.getTabContentResult = ["title": "Example", "url": "https://example.com", "content": "Hello world"]
        let handler = try XCTUnwrap(handlerMap["get_tab_content"])
        let args: [String: JSONValue] = ["index": .int(1)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.getTabContentCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertTrue(text.contains("Hello world"))
    }

    func testGetTabContentByURLCallsProvider() async throws {
        provider.getTabContentResult = ["title": "Example", "url": "https://example.com", "content": "Page content"]
        let handler = try XCTUnwrap(handlerMap["get_tab_content"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.getTabContentCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testGetTabContentMissingIndexAndURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["get_tab_content"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.getTabContentCalled)
    }

    func testGetTabContentPropagatesError() async throws {
        provider.getTabContentError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["get_tab_content"])
        let args: [String: JSONValue] = ["index": .int(1)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - new_tab

    func testNewTabCallsProviderWithURL() async throws {
        provider.newTabResult = ["success": true, "url": "https://example.com"]
        let handler = try XCTUnwrap(handlerMap["new_tab"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.newTabCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testNewTabMissingURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["new_tab"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.newTabCalled)
    }

    func testNewTabPropagatesError() async throws {
        provider.newTabError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["new_tab"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

    // MARK: - reload_tab

    func testReloadTabByIndexCallsProvider() async throws {
        provider.reloadTabResult = ["success": true, "message": "Tab reloaded"]
        let handler = try XCTUnwrap(handlerMap["reload_tab"])
        let args: [String: JSONValue] = ["index": .int(1)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.reloadTabCalled)
        XCTAssertFalse(result.isError ?? false)
        let text = try XCTUnwrap(result.content.first?.text)
        XCTAssertFalse(text.isEmpty)
    }

    func testReloadTabByURLCallsProvider() async throws {
        provider.reloadTabResult = ["success": true, "message": "Tab reloaded"]
        let handler = try XCTUnwrap(handlerMap["reload_tab"])
        let args: [String: JSONValue] = ["url": .string("https://example.com")]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.reloadTabCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testReloadTabMissingIndexAndURLReturnsError() async throws {
        let handler = try XCTUnwrap(handlerMap["reload_tab"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(result.isError ?? false)
        XCTAssertFalse(provider.reloadTabCalled)
    }

    func testReloadTabPropagatesError() async throws {
        provider.reloadTabError = TestError.generic("simulated")
        let handler = try XCTUnwrap(handlerMap["reload_tab"])
        let args: [String: JSONValue] = ["index": .int(1)]
        let result = try await handler.handle(arguments: args)

        XCTAssertTrue(result.isError ?? false)
    }

}

// MARK: - SafariBridgeScriptTests

/// These tests verify the AppleScript strings generated by SafariBridge
/// WITHOUT executing them, per the AppleScriptBridge testing rules.
final class SafariBridgeScriptTests: XCTestCase {

    var bridge: SafariBridge!
    var executor: MockScriptExecutor!

    override func setUp() {
        super.setUp()
        executor = MockScriptExecutor()
        bridge = SafariBridge(executor: executor)
    }

    // MARK: - listOpenTabs script

    func testListOpenTabsExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listOpenTabs()
        XCTAssertTrue(executor.executeCalled)
    }

    func testListOpenTabsScriptContainsSafari() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listOpenTabs()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testListOpenTabsScriptIteratesWindows() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listOpenTabs()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.contains("window") || script.contains("tab"),
            "Script should reference windows or tabs, got: \(script)"
        )
    }

    // MARK: - listReadingList script

    func testListReadingListExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listReadingList()
        XCTAssertTrue(executor.executeCalled)
    }

    func testListReadingListScriptContainsSafariOrReadingList() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listReadingList()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari") || script.lowercased().contains("reading"),
            "Script should mention safari or reading list, got: \(script)"
        )
    }

    // MARK: - searchBookmarks script

    func testSearchBookmarksExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchBookmarks(query: "swift")
        XCTAssertTrue(executor.executeCalled)
    }

    func testSearchBookmarksScriptContainsQuery() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchBookmarks(query: "myUniqueQuery")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.contains("myUniqueQuery"),
            "Script should embed the query, got: \(script)"
        )
    }

    func testSearchBookmarksScriptMentionsBookmarks() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchBookmarks(query: "test")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("bookmark"),
            "Script should mention bookmarks, got: \(script)"
        )
    }

    // MARK: - searchHistory script

    func testSearchHistoryExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchHistory(query: "github", daysBack: 7)
        XCTAssertTrue(executor.executeCalled)
    }

    func testSearchHistoryScriptContainsQuery() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchHistory(query: "uniqueHistoryQuery", daysBack: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.contains("uniqueHistoryQuery"),
            "Script should embed the query, got: \(script)"
        )
    }

    func testSearchHistoryScriptMentionsHistory() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.searchHistory(query: "test", daysBack: 30)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("histor") || script.lowercased().contains("safari"),
            "Script should mention history or safari, got: \(script)"
        )
    }

    // MARK: - closeTab script

    func testCloseTabByIndexExecutesAppleScript() async throws {
        executor.resultToReturn = "{success: true}"
        _ = try await bridge.closeTab(index: 2, url: nil, confirmation: true)
        XCTAssertTrue(executor.executeCalled)
    }

    func testCloseTabScriptContainsSafari() async throws {
        executor.resultToReturn = "{success: true}"
        _ = try await bridge.closeTab(index: 1, url: nil, confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testCloseTabScriptReferencesCloseOrTab() async throws {
        executor.resultToReturn = "{success: true}"
        _ = try await bridge.closeTab(index: 1, url: nil, confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("close") || script.lowercased().contains("tab"),
            "Script should mention close or tab, got: \(script)"
        )
    }

    // MARK: - addToReadingList script

    func testAddToReadingListExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addToReadingList(url: "https://example.com", title: nil)
        XCTAssertTrue(executor.executeCalled)
    }

    func testAddToReadingListScriptContainsSafariAndURL() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addToReadingList(url: "https://uniqueurl.example.com", title: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
        XCTAssertTrue(
            script.contains("uniqueurl.example.com"),
            "Script should embed the URL, got: \(script)"
        )
    }

    func testAddToReadingListScriptMentionsReadingList() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addToReadingList(url: "https://example.com", title: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("reading"),
            "Script should mention reading list, got: \(script)"
        )
    }

    // MARK: - addBookmark script

    func testAddBookmarkExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addBookmark(url: "https://example.com", title: "Example", folderName: nil)
        XCTAssertTrue(executor.executeCalled)
    }

    func testAddBookmarkScriptContainsSafariAndURL() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addBookmark(url: "https://uniquebookmarkurl.com", title: "Test", folderName: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
        XCTAssertTrue(
            script.contains("uniquebookmarkurl.com"),
            "Script should embed the URL, got: \(script)"
        )
    }

    func testAddBookmarkScriptMentionsBookmark() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Added\"}"
        _ = try await bridge.addBookmark(url: "https://example.com", title: "Test", folderName: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("bookmark"),
            "Script should mention bookmark, got: \(script)"
        )
    }

    // MARK: - deleteBookmark script

    func testDeleteBookmarkExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Deleted\"}"
        _ = try await bridge.deleteBookmark(title: "Example", url: nil, confirmation: true)
        XCTAssertTrue(executor.executeCalled)
    }

    func testDeleteBookmarkScriptContainsSafari() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Deleted\"}"
        _ = try await bridge.deleteBookmark(title: "UniqueTitle123", url: nil, confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testDeleteBookmarkScriptEmbedsTitleOrURL() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Deleted\"}"
        _ = try await bridge.deleteBookmark(title: "UniqueSearchTitle", url: nil, confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.contains("UniqueSearchTitle"),
            "Script should embed the title, got: \(script)"
        )
    }

    // MARK: - listBookmarkFolders script

    func testListBookmarkFoldersExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listBookmarkFolders()
        XCTAssertTrue(executor.executeCalled)
    }

    func testListBookmarkFoldersScriptContainsSafari() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listBookmarkFolders()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testListBookmarkFoldersScriptMentionsFolders() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.listBookmarkFolders()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("folder") || script.lowercased().contains("bookmark"),
            "Script should mention folder or bookmark, got: \(script)"
        )
    }

    // MARK: - createBookmarkFolder script

    func testCreateBookmarkFolderExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"name\":\"NewFolder\"}"
        _ = try await bridge.createBookmarkFolder(name: "NewFolder")
        XCTAssertTrue(executor.executeCalled)
    }

    func testCreateBookmarkFolderScriptContainsSafariAndName() async throws {
        executor.resultToReturn = "{\"success\":true,\"name\":\"UniqueFolder\"}"
        _ = try await bridge.createBookmarkFolder(name: "UniqueFolder")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
        XCTAssertTrue(
            script.contains("UniqueFolder"),
            "Script should embed the folder name, got: \(script)"
        )
    }

    // MARK: - findDuplicateTabs script

    func testFindDuplicateTabsExecutesAppleScript() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.findDuplicateTabs()
        XCTAssertTrue(executor.executeCalled)
    }

    func testFindDuplicateTabsScriptContainsSafari() async throws {
        executor.resultToReturn = "[]"
        _ = try await bridge.findDuplicateTabs()
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    // MARK: - closeTabsMatching script

    func testCloseTabsMatchingExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"closedCount\":0,\"message\":\"Closed 0 tabs\"}"
        _ = try await bridge.closeTabsMatching(pattern: "example.com", confirmation: true)
        XCTAssertTrue(executor.executeCalled)
    }

    func testCloseTabsMatchingScriptContainsPattern() async throws {
        executor.resultToReturn = "{\"success\":true,\"closedCount\":0,\"message\":\"Closed 0 tabs\"}"
        _ = try await bridge.closeTabsMatching(pattern: "uniquepattern.io", confirmation: true)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.contains("uniquepattern.io"),
            "Script should embed the pattern, got: \(script)"
        )
    }

    // MARK: - getTabContent script

    func testGetTabContentExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"title\":\"Test\",\"url\":\"https://example.com\",\"content\":\"Hello\"}"
        _ = try await bridge.getTabContent(index: 1, url: nil)
        XCTAssertTrue(executor.executeCalled)
    }

    func testGetTabContentScriptContainsSafari() async throws {
        executor.resultToReturn = "{\"title\":\"Test\",\"url\":\"https://example.com\",\"content\":\"Hello\"}"
        _ = try await bridge.getTabContent(index: 1, url: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testGetTabContentScriptMentionsJavaScript() async throws {
        executor.resultToReturn = "{\"title\":\"Test\",\"url\":\"https://example.com\",\"content\":\"Hello\"}"
        _ = try await bridge.getTabContent(index: 1, url: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("javascript") || script.lowercased().contains("innertext"),
            "Script should mention JavaScript or innerText, got: \(script)"
        )
    }

    // MARK: - newTab script

    func testNewTabExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"url\":\"https://example.com\"}"
        _ = try await bridge.newTab(url: "https://example.com")
        XCTAssertTrue(executor.executeCalled)
    }

    func testNewTabScriptContainsSafariAndURL() async throws {
        executor.resultToReturn = "{\"success\":true,\"url\":\"https://uniquenewtab.com\"}"
        _ = try await bridge.newTab(url: "https://uniquenewtab.com")
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
        XCTAssertTrue(
            script.contains("uniquenewtab.com"),
            "Script should embed the URL, got: \(script)"
        )
    }

    // MARK: - reloadTab script

    func testReloadTabExecutesAppleScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Reloaded\"}"
        _ = try await bridge.reloadTab(index: 1, url: nil)
        XCTAssertTrue(executor.executeCalled)
    }

    func testReloadTabScriptContainsSafari() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Reloaded\"}"
        _ = try await bridge.reloadTab(index: 1, url: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("safari"),
            "Script should mention Safari, got: \(script)"
        )
    }

    func testReloadTabScriptMentionsReloadOrJavaScript() async throws {
        executor.resultToReturn = "{\"success\":true,\"message\":\"Reloaded\"}"
        _ = try await bridge.reloadTab(index: 1, url: nil)
        let script = try XCTUnwrap(executor.lastScript)
        XCTAssertTrue(
            script.lowercased().contains("reload") || script.lowercased().contains("javascript"),
            "Script should mention reload or JavaScript, got: \(script)"
        )
    }

}
