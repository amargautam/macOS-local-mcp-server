import XCTest
@testable import MacOSLocalMCP

final class FinderToolTests: XCTestCase {

    var mock: MockFinderProvider!
    var handlers: [String: MCPToolHandler]!

    override func setUp() {
        super.setUp()
        mock = MockFinderProvider()
        let tool = FinderTool(provider: mock)
        handlers = Dictionary(uniqueKeysWithValues: tool.createHandlers().map { ($0.toolName, $0) })
    }

    // MARK: - Helpers

    private func call(_ toolName: String, args: [String: JSONValue]?) async throws -> MCPToolResult {
        guard let handler = handlers[toolName] else {
            XCTFail("No handler registered for \(toolName)")
            return .error("missing handler")
        }
        return try await handler.handle(arguments: args)
    }

    private func decodeArray(_ result: MCPToolResult) throws -> [[String: Any]] {
        guard let text = result.content.first?.text,
              let data = text.data(using: .utf8),
              let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("Could not decode result as array: \(result.content.first?.text ?? "<nil>")")
            return []
        }
        return arr
    }

    private func decodeObject(_ result: MCPToolResult) throws -> [String: Any] {
        guard let text = result.content.first?.text,
              let data = text.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Could not decode result as object: \(result.content.first?.text ?? "<nil>")")
            return [:]
        }
        return obj
    }

    // MARK: - ClosureToolHandler Tests

    func testClosureToolHandlerToolName() {
        let handler = ClosureToolHandler(toolName: "my_tool") { _ in .text("ok") }
        XCTAssertEqual(handler.toolName, "my_tool")
    }

    func testClosureToolHandlerCallsClosure() async throws {
        var called = false
        let handler = ClosureToolHandler(toolName: "t") { _ in
            called = true
            return .text("done")
        }
        let result = try await handler.handle(arguments: nil)
        XCTAssertTrue(called)
        XCTAssertEqual(result.content.first?.text, "done")
    }

    func testClosureToolHandlerPassesArguments() async throws {
        var captured: [String: JSONValue]?
        let handler = ClosureToolHandler(toolName: "t") { args in
            captured = args
            return .text("ok")
        }
        let args: [String: JSONValue] = ["key": .string("value")]
        _ = try await handler.handle(arguments: args)
        XCTAssertEqual(captured?["key"], .string("value"))
    }

    func testClosureToolHandlerPropagatesError() async {
        let expected = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let handler = ClosureToolHandler(toolName: "t") { _ in throw expected }
        do {
            _ = try await handler.handle(arguments: nil)
            XCTFail("Should have thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 42)
        }
    }

    // MARK: - FinderTool Registration

    func testFinderToolCreatesAllSixHandlers() {
        XCTAssertEqual(handlers.count, 6)
        XCTAssertNotNil(handlers["spotlight_search"])
        XCTAssertNotNil(handlers["spotlight_search_content"])
        XCTAssertNotNil(handlers["get_file_metadata"])
        XCTAssertNotNil(handlers["set_finder_tags"])
        XCTAssertNotNil(handlers["list_finder_tags"])
        XCTAssertNotNil(handlers["get_tagged_files"])
    }

    // MARK: - spotlight_search

    func testSpotlightSearchHappyPath() async throws {
        mock.spotlightSearchResult = [
            ["path": "/Users/test/file.pdf", "name": "file.pdf", "kind": "PDF Document"]
        ]
        let result = try await call("spotlight_search", args: ["query": .string("file")])
        XCTAssertTrue(mock.spotlightSearchCalled)
        XCTAssertEqual(mock.lastSearchQuery, "file")
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr.first?["path"] as? String, "/Users/test/file.pdf")
    }

    func testSpotlightSearchPassesOptionalParams() async throws {
        mock.spotlightSearchResult = []
        _ = try await call("spotlight_search", args: [
            "query": .string("doc"),
            "kind": .string("pdf"),
            "directory": .string("/Users/test"),
            "max_results": .int(5)
        ])
        XCTAssertTrue(mock.spotlightSearchCalled)
    }

    func testSpotlightSearchMissingQueryReturnsError() async throws {
        let result = try await call("spotlight_search", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.spotlightSearchCalled)
    }

    func testSpotlightSearchMissingQueryInArgsReturnsError() async throws {
        let result = try await call("spotlight_search", args: ["kind": .string("pdf")])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.spotlightSearchCalled)
    }

    func testSpotlightSearchProviderThrowsReturnsError() async throws {
        mock.spotlightSearchError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mdfind failed"])
        let result = try await call("spotlight_search", args: ["query": .string("test")])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("mdfind failed") ?? false)
    }

    func testSpotlightSearchEmptyResultsReturnsEmptyArray() async throws {
        mock.spotlightSearchResult = []
        let result = try await call("spotlight_search", args: ["query": .string("nothing")])
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 0)
    }

    // MARK: - spotlight_search_content

    func testSpotlightSearchContentHappyPath() async throws {
        mock.spotlightSearchContentResult = [
            ["path": "/docs/report.docx", "name": "report.docx"]
        ]
        let result = try await call("spotlight_search_content", args: ["query": .string("quarterly")])
        XCTAssertTrue(mock.spotlightSearchContentCalled)
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 1)
        XCTAssertEqual(arr.first?["path"] as? String, "/docs/report.docx")
    }

    func testSpotlightSearchContentPassesOptionalParams() async throws {
        mock.spotlightSearchContentResult = []
        _ = try await call("spotlight_search_content", args: [
            "query": .string("budget"),
            "directory": .string("/Users/test/docs"),
            "max_results": .int(10)
        ])
        XCTAssertTrue(mock.spotlightSearchContentCalled)
    }

    func testSpotlightSearchContentMissingQueryReturnsError() async throws {
        let result = try await call("spotlight_search_content", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.spotlightSearchContentCalled)
    }

    func testSpotlightSearchContentMissingQueryInArgsReturnsError() async throws {
        let result = try await call("spotlight_search_content", args: ["directory": .string("/tmp")])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.spotlightSearchContentCalled)
    }

    func testSpotlightSearchContentProviderThrowsReturnsError() async throws {
        mock.spotlightSearchContentError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "content search failed"])
        let result = try await call("spotlight_search_content", args: ["query": .string("test")])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("content search failed") ?? false)
    }

    // MARK: - get_file_metadata

    func testGetFileMetadataHappyPath() async throws {
        mock.getFileMetadataResult = [
            "path": "/Users/test/doc.pdf",
            "size": 12345,
            "created": "2024-01-01T00:00:00Z",
            "kind": "PDF Document"
        ]
        let result = try await call("get_file_metadata", args: ["path": .string("/Users/test/doc.pdf")])
        XCTAssertTrue(mock.getFileMetadataCalled)
        XCTAssertEqual(mock.lastFilePath, "/Users/test/doc.pdf")
        XCTAssertNil(result.isError)
        let obj = try decodeObject(result)
        XCTAssertEqual(obj["path"] as? String, "/Users/test/doc.pdf")
        XCTAssertEqual(obj["kind"] as? String, "PDF Document")
    }

    func testGetFileMetadataMissingPathReturnsError() async throws {
        let result = try await call("get_file_metadata", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.getFileMetadataCalled)
    }

    func testGetFileMetadataMissingPathInArgsReturnsError() async throws {
        let result = try await call("get_file_metadata", args: ["other": .string("value")])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.getFileMetadataCalled)
    }

    func testGetFileMetadataProviderThrowsReturnsError() async throws {
        mock.getFileMetadataError = NSError(domain: "test", code: 3, userInfo: [NSLocalizedDescriptionKey: "file not found"])
        let result = try await call("get_file_metadata", args: ["path": .string("/nonexistent")])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("file not found") ?? false)
    }

    // MARK: - set_finder_tags

    func testSetFinderTagsHappyPath() async throws {
        mock.setFinderTagsResult = ["path": "/Users/test/doc.pdf", "tags": ["work", "urgent"], "success": true]
        let result = try await call("set_finder_tags", args: [
            "path": .string("/Users/test/doc.pdf"),
            "tags": .array([.string("work"), .string("urgent")])
        ])
        XCTAssertTrue(mock.setFinderTagsCalled)
        XCTAssertEqual(mock.lastFilePath, "/Users/test/doc.pdf")
        XCTAssertEqual(mock.lastSetTags, ["work", "urgent"])
        XCTAssertNil(result.isError)
    }

    func testSetFinderTagsMissingPathReturnsError() async throws {
        let result = try await call("set_finder_tags", args: ["tags": .array([.string("work")])])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.setFinderTagsCalled)
    }

    func testSetFinderTagsMissingTagsReturnsError() async throws {
        let result = try await call("set_finder_tags", args: ["path": .string("/tmp/file")])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.setFinderTagsCalled)
    }

    func testSetFinderTagsMissingBothReturnsError() async throws {
        let result = try await call("set_finder_tags", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.setFinderTagsCalled)
    }

    func testSetFinderTagsEmptyTagsArray() async throws {
        mock.setFinderTagsResult = ["path": "/tmp/file", "tags": [], "success": true]
        let result = try await call("set_finder_tags", args: [
            "path": .string("/tmp/file"),
            "tags": .array([])
        ])
        XCTAssertTrue(mock.setFinderTagsCalled)
        XCTAssertEqual(mock.lastSetTags, [])
        XCTAssertNil(result.isError)
    }

    func testSetFinderTagsProviderThrowsReturnsError() async throws {
        mock.setFinderTagsError = NSError(domain: "test", code: 4, userInfo: [NSLocalizedDescriptionKey: "xattr failed"])
        let result = try await call("set_finder_tags", args: [
            "path": .string("/tmp/file"),
            "tags": .array([.string("test")])
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("xattr failed") ?? false)
    }

    func testSetFinderTagsNonStringTagsAreSkipped() async throws {
        mock.setFinderTagsResult = ["success": true]
        let result = try await call("set_finder_tags", args: [
            "path": .string("/tmp/file"),
            "tags": .array([.string("valid"), .int(42), .string("also-valid")])
        ])
        XCTAssertTrue(mock.setFinderTagsCalled)
        // Only string values should be extracted
        XCTAssertEqual(mock.lastSetTags, ["valid", "also-valid"])
        XCTAssertNil(result.isError)
    }

    // MARK: - list_finder_tags

    func testListFinderTagsHappyPath() async throws {
        mock.listFinderTagsResult = [
            ["name": "work", "color": "blue"],
            ["name": "urgent", "color": "red"]
        ]
        let result = try await call("list_finder_tags", args: nil)
        XCTAssertTrue(mock.listFinderTagsCalled)
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr.first?["name"] as? String, "work")
    }

    func testListFinderTagsIgnoresArguments() async throws {
        mock.listFinderTagsResult = []
        // list_finder_tags takes no params — extra args should be ignored
        let result = try await call("list_finder_tags", args: ["extra": .string("ignored")])
        XCTAssertTrue(mock.listFinderTagsCalled)
        XCTAssertNil(result.isError)
    }

    func testListFinderTagsProviderThrowsReturnsError() async throws {
        mock.listFinderTagsError = NSError(domain: "test", code: 5, userInfo: [NSLocalizedDescriptionKey: "tag list failed"])
        let result = try await call("list_finder_tags", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("tag list failed") ?? false)
    }

    func testListFinderTagsEmptyResultsReturnsEmptyArray() async throws {
        mock.listFinderTagsResult = []
        let result = try await call("list_finder_tags", args: nil)
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 0)
    }

    // MARK: - get_tagged_files

    func testGetTaggedFilesHappyPath() async throws {
        mock.getTaggedFilesResult = [
            ["path": "/Users/test/important.pdf", "name": "important.pdf"],
            ["path": "/Users/test/notes.txt", "name": "notes.txt"]
        ]
        let result = try await call("get_tagged_files", args: ["tag": .string("urgent")])
        XCTAssertTrue(mock.getTaggedFilesCalled)
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr.first?["path"] as? String, "/Users/test/important.pdf")
    }

    func testGetTaggedFilesMissingTagReturnsError() async throws {
        let result = try await call("get_tagged_files", args: nil)
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.getTaggedFilesCalled)
    }

    func testGetTaggedFilesMissingTagInArgsReturnsError() async throws {
        let result = try await call("get_tagged_files", args: ["other": .string("value")])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(mock.getTaggedFilesCalled)
    }

    func testGetTaggedFilesProviderThrowsReturnsError() async throws {
        mock.getTaggedFilesError = NSError(domain: "test", code: 6, userInfo: [NSLocalizedDescriptionKey: "tag search failed"])
        let result = try await call("get_tagged_files", args: ["tag": .string("urgent")])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content.first?.text?.contains("tag search failed") ?? false)
    }

    func testGetTaggedFilesEmptyResultsReturnsEmptyArray() async throws {
        mock.getTaggedFilesResult = []
        let result = try await call("get_tagged_files", args: ["tag": .string("nonexistent")])
        XCTAssertNil(result.isError)
        let arr = try decodeArray(result)
        XCTAssertEqual(arr.count, 0)
    }
}
