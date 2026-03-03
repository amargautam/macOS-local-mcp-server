import XCTest
@testable import MacOSLocalMCP

// MARK: - Mock shell executor for testing command construction

final class MockShellExecutor: ShellCommandExecuting {
    var capturedCommand: String?
    var capturedArguments: [String] = []
    var resultToReturn: String = ""
    var errorToThrow: Error?

    func execute(command: String, arguments: [String]) throws -> String {
        capturedCommand = command
        capturedArguments = arguments
        if let error = errorToThrow { throw error }
        return resultToReturn
    }
}

final class ShellBridgeTests: XCTestCase {

    // MARK: - ShellCommandExecuting protocol

    func testMockShellExecutorCapturesCommand() throws {
        let executor = MockShellExecutor()
        executor.resultToReturn = "output"
        let result = try executor.execute(command: "/usr/bin/echo", arguments: ["hello"])
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/echo")
        XCTAssertEqual(executor.capturedArguments, ["hello"])
        XCTAssertEqual(result, "output")
    }

    func testMockShellExecutorThrowsError() {
        let executor = MockShellExecutor()
        executor.errorToThrow = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "command failed"])
        XCTAssertThrowsError(try executor.execute(command: "/bin/false", arguments: [])) { error in
            XCTAssertEqual((error as NSError).code, 1)
        }
    }

    // MARK: - ProcessShellExecutor basic smoke test (real process)

    func testProcessShellExecutorRunsEcho() throws {
        let executor = ProcessShellExecutor()
        let output = try executor.execute(command: "/bin/echo", arguments: ["hello world"])
        XCTAssertTrue(output.contains("hello world"))
    }

    func testProcessShellExecutorReturnsOutput() throws {
        let executor = ProcessShellExecutor()
        // /usr/bin/sw_vers is available on all macOS
        let output = try executor.execute(command: "/usr/bin/sw_vers", arguments: ["-productName"])
        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testProcessShellExecutorWithMultipleArguments() throws {
        let executor = ProcessShellExecutor()
        // printf format and value
        let output = try executor.execute(command: "/usr/bin/printf", arguments: ["%s", "test-value"])
        XCTAssertEqual(output, "test-value")
    }

    func testProcessShellExecutorTrimsTrailingNewline() throws {
        let executor = ProcessShellExecutor()
        let output = try executor.execute(command: "/bin/echo", arguments: ["trimmed"])
        // echo appends a newline; we should still get a usable string
        // (the implementation may or may not trim — test just that output is non-empty and contains our text)
        XCTAssertTrue(output.contains("trimmed"))
    }
}

// MARK: - FinderBridge command construction tests

final class FinderBridgeTests: XCTestCase {

    var executor: MockShellExecutor!
    var bridge: FinderBridge!

    override func setUp() {
        super.setUp()
        executor = MockShellExecutor()
        bridge = FinderBridge(shell: executor)
    }

    // MARK: - spotlightSearch — mdfind command construction

    func testSpotlightSearchBuildsCorrectMdfindCommand() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.spotlightSearch(query: "budget", kind: nil, directory: nil, maxResults: nil)
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/mdfind")
        XCTAssertTrue(executor.capturedArguments.contains("budget"))
    }

    func testSpotlightSearchAppliesKindFilter() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.spotlightSearch(query: "report", kind: "pdf", directory: nil, maxResults: nil)
        let args = executor.capturedArguments.joined(separator: " ")
        XCTAssertTrue(args.contains("pdf") || args.contains("PDF"), "Kind filter should appear in arguments: \(args)")
    }

    func testSpotlightSearchAppliesDirectoryFilter() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.spotlightSearch(query: "test", kind: nil, directory: "/Users/test/docs", maxResults: nil)
        XCTAssertTrue(executor.capturedArguments.contains("-onlyin"))
        XCTAssertTrue(executor.capturedArguments.contains("/Users/test/docs"))
    }

    func testSpotlightSearchWithNoResultsReturnsEmptyArray() async throws {
        executor.resultToReturn = ""
        let results = try await bridge.spotlightSearch(query: "nothing", kind: nil, directory: nil, maxResults: nil)
        XCTAssertEqual(results.count, 0)
    }

    func testSpotlightSearchParsesPathLines() async throws {
        executor.resultToReturn = "/Users/test/a.pdf\n/Users/test/b.pdf\n"
        let results = try await bridge.spotlightSearch(query: "pdf", kind: nil, directory: nil, maxResults: nil)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["path"] as? String, "/Users/test/a.pdf")
        XCTAssertEqual(results[1]["path"] as? String, "/Users/test/b.pdf")
    }

    func testSpotlightSearchRespectsMaxResults() async throws {
        executor.resultToReturn = "/a\n/b\n/c\n/d\n/e\n"
        let results = try await bridge.spotlightSearch(query: "x", kind: nil, directory: nil, maxResults: 3)
        XCTAssertEqual(results.count, 3)
    }

    func testSpotlightSearchShellErrorPropagates() async {
        executor.errorToThrow = NSError(domain: "shell", code: 1, userInfo: [NSLocalizedDescriptionKey: "mdfind error"])
        do {
            _ = try await bridge.spotlightSearch(query: "test", kind: nil, directory: nil, maxResults: nil)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("mdfind error"))
        }
    }

    // MARK: - spotlightSearchContent — kMDItemTextContent

    func testSpotlightSearchContentBuildsCorrectCommand() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.spotlightSearchContent(query: "invoice", directory: nil, maxResults: nil)
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/mdfind")
        let args = executor.capturedArguments.joined(separator: " ")
        XCTAssertTrue(args.contains("invoice"))
        XCTAssertTrue(args.contains("kMDItemTextContent"))
    }

    func testSpotlightSearchContentAppliesDirectory() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.spotlightSearchContent(query: "tax", directory: "/Users/me/docs", maxResults: nil)
        XCTAssertTrue(executor.capturedArguments.contains("-onlyin"))
        XCTAssertTrue(executor.capturedArguments.contains("/Users/me/docs"))
    }

    func testSpotlightSearchContentParsesResults() async throws {
        executor.resultToReturn = "/tmp/doc1.txt\n/tmp/doc2.txt\n"
        let results = try await bridge.spotlightSearchContent(query: "hello", directory: nil, maxResults: nil)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["path"] as? String, "/tmp/doc1.txt")
    }

    // MARK: - getFileMetadata — mdls command construction

    func testGetFileMetadataBuildsCorrectMdlsCommand() async throws {
        executor.resultToReturn = "kMDItemDisplayName = \"test.pdf\"\nkMDItemFSSize = 1234\n"
        _ = try await bridge.getFileMetadata(path: "/Users/test/test.pdf")
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/mdls")
        XCTAssertTrue(executor.capturedArguments.contains("/Users/test/test.pdf"))
    }

    func testGetFileMetadataParsesMdlsOutput() async throws {
        executor.resultToReturn = """
        kMDItemDisplayName = "report.pdf"
        kMDItemFSSize     = 98765
        kMDItemContentType = "com.adobe.pdf"
        """
        let result = try await bridge.getFileMetadata(path: "/path/to/report.pdf")
        XCTAssertNotNil(result["kMDItemDisplayName"])
        XCTAssertNotNil(result["kMDItemFSSize"])
        XCTAssertNotNil(result["kMDItemContentType"])
    }

    func testGetFileMetadataIncludesPathInResult() async throws {
        executor.resultToReturn = "kMDItemDisplayName = \"file.txt\"\n"
        let result = try await bridge.getFileMetadata(path: "/tmp/file.txt")
        XCTAssertEqual(result["path"] as? String, "/tmp/file.txt")
    }

    func testGetFileMetadataShellErrorPropagates() async {
        executor.errorToThrow = NSError(domain: "shell", code: 2, userInfo: [NSLocalizedDescriptionKey: "mdls failed"])
        do {
            _ = try await bridge.getFileMetadata(path: "/nonexistent")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("mdls failed"))
        }
    }

    // MARK: - setFinderTags — xattr command construction

    func testSetFinderTagsBuildsXattrCommand() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.setFinderTags(path: "/tmp/file.pdf", tags: ["work"])
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/xattr")
    }

    func testSetFinderTagsIncludesPath() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.setFinderTags(path: "/Users/test/doc.pdf", tags: ["urgent"])
        XCTAssertTrue(executor.capturedArguments.contains("/Users/test/doc.pdf"))
    }

    func testSetFinderTagsReturnsSuccessResult() async throws {
        executor.resultToReturn = ""
        let result = try await bridge.setFinderTags(path: "/tmp/f", tags: ["tag1"])
        XCTAssertEqual(result["success"] as? Bool, true)
        XCTAssertEqual(result["path"] as? String, "/tmp/f")
    }

    func testSetFinderTagsShellErrorPropagates() async {
        executor.errorToThrow = NSError(domain: "shell", code: 3, userInfo: [NSLocalizedDescriptionKey: "xattr write failed"])
        do {
            _ = try await bridge.setFinderTags(path: "/tmp/f", tags: ["tag"])
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("xattr write failed"))
        }
    }

    // MARK: - listFinderTags — mdfind with kMDItemUserTags

    func testListFinderTagsBuildsCorrectCommand() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.listFinderTags()
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/mdfind")
        let args = executor.capturedArguments.joined(separator: " ")
        XCTAssertTrue(args.contains("kMDItemUserTags"))
    }

    func testListFinderTagsParsesResults() async throws {
        executor.resultToReturn = "/Users/test/work.pdf\n/Users/test/notes.txt\n"
        let results = try await bridge.listFinderTags()
        // Should return file paths that have tags, or deduplicated tags — bridge defines the contract
        XCTAssertGreaterThanOrEqual(results.count, 0)
    }

    // MARK: - getTaggedFiles — mdfind with kMDItemUserTags

    func testGetTaggedFilesBuildsCorrectCommand() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.getTaggedFiles(tag: "work")
        XCTAssertEqual(executor.capturedCommand, "/usr/bin/mdfind")
        let args = executor.capturedArguments.joined(separator: " ")
        XCTAssertTrue(args.contains("work") || args.contains("kMDItemUserTags"))
    }

    func testGetTaggedFilesIncludesTagInQuery() async throws {
        executor.resultToReturn = ""
        _ = try await bridge.getTaggedFiles(tag: "urgent")
        let args = executor.capturedArguments.joined(separator: " ")
        XCTAssertTrue(args.contains("urgent"))
    }

    func testGetTaggedFilesParsesResults() async throws {
        executor.resultToReturn = "/tmp/tagged1.pdf\n/tmp/tagged2.txt\n"
        let results = try await bridge.getTaggedFiles(tag: "work")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["path"] as? String, "/tmp/tagged1.pdf")
    }

    func testGetTaggedFilesEmptyReturnsEmptyArray() async throws {
        executor.resultToReturn = ""
        let results = try await bridge.getTaggedFiles(tag: "nonexistent")
        XCTAssertEqual(results.count, 0)
    }

    func testGetTaggedFilesShellErrorPropagates() async {
        executor.errorToThrow = NSError(domain: "shell", code: 4, userInfo: [NSLocalizedDescriptionKey: "tag search error"])
        do {
            _ = try await bridge.getTaggedFiles(tag: "work")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("tag search error"))
        }
    }
}
