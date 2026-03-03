import XCTest
@testable import MacOSLocalMCP

// MARK: - ShortcutsTool Tests

final class ShortcutsToolTests: XCTestCase {

    var provider: MockShortcutsProvider!
    var tool: ShortcutsTool!
    var handlers: [String: MCPToolHandler]!

    override func setUp() {
        super.setUp()
        provider = MockShortcutsProvider()
        tool = ShortcutsTool(provider: provider)
        let handlerList = tool.createHandlers()
        handlers = Dictionary(uniqueKeysWithValues: handlerList.map { ($0.toolName, $0) })
    }

    // MARK: - createHandlers

    func testCreateHandlersReturnsThreeHandlers() {
        let handlerList = tool.createHandlers()
        XCTAssertEqual(handlerList.count, 3)
    }

    func testCreateHandlersContainsListShortcuts() {
        XCTAssertNotNil(handlers["list_shortcuts"])
    }

    func testCreateHandlersContainsRunShortcut() {
        XCTAssertNotNil(handlers["run_shortcut"])
    }

    func testCreateHandlersContainsGetShortcutDetails() {
        XCTAssertNotNil(handlers["get_shortcut_details"])
    }

    // MARK: - list_shortcuts

    func testListShortcutsCallsProvider() async throws {
        provider.listShortcutsResult = [
            ["name": "Send Daily Report", "folder": "Work"],
            ["name": "Morning Routine", "folder": "Personal"]
        ]

        let handler = try XCTUnwrap(handlers["list_shortcuts"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertTrue(provider.listShortcutsCalled)
        XCTAssertFalse(result.isError ?? false)
    }

    func testListShortcutsReturnsFormattedText() async throws {
        provider.listShortcutsResult = [
            ["name": "Send Daily Report", "folder": "Work"],
            ["name": "Morning Routine", "folder": "Personal"]
        ]

        let handler = try XCTUnwrap(handlers["list_shortcuts"])
        let result = try await handler.handle(arguments: nil)

        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Send Daily Report"))
        XCTAssertTrue(text.contains("Morning Routine"))
    }

    func testListShortcutsEmptyResultReturnsGracefulMessage() async throws {
        provider.listShortcutsResult = []

        let handler = try XCTUnwrap(handlers["list_shortcuts"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func testListShortcutsErrorReturnsErrorResult() async throws {
        provider.listShortcutsError = ShortcutsError.commandFailed("shortcuts not available")

        let handler = try XCTUnwrap(handlers["list_shortcuts"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - run_shortcut

    func testRunShortcutCallsProviderWithName() async throws {
        provider.runShortcutResult = ["output": "Done", "success": true]

        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Send Daily Report"),
            "confirmation": .bool(true)
        ]
        _ = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.runShortcutCalled)
        XCTAssertEqual(provider.lastRunName, "Send Daily Report")
    }

    func testRunShortcutPassesInputToProvider() async throws {
        provider.runShortcutResult = ["output": "Processed", "success": true]

        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Process Text"),
            "input": .string("hello world"),
            "confirmation": .bool(true)
        ]
        _ = try await handler.handle(arguments: args)

        XCTAssertEqual(provider.lastRunInput, "hello world")
    }

    func testRunShortcutWithNoInputPassesNilToProvider() async throws {
        provider.runShortcutResult = ["output": "", "success": true]

        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("My Shortcut"),
            "confirmation": .bool(true)
        ]
        _ = try await handler.handle(arguments: args)

        XCTAssertNil(provider.lastRunInput)
    }

    func testRunShortcutWithoutConfirmationReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Send Report")
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.runShortcutCalled)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.lowercased().contains("confirmation"))
    }

    func testRunShortcutWithConfirmationFalseReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Send Report"),
            "confirmation": .bool(false)
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.runShortcutCalled)
    }

    func testRunShortcutMissingNameReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "confirmation": .bool(true)
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.runShortcutCalled)
    }

    func testRunShortcutMissingArgumentsReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.runShortcutCalled)
    }

    func testRunShortcutReturnsFormattedOutput() async throws {
        provider.runShortcutResult = ["output": "Report sent successfully", "success": true]

        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Send Report"),
            "confirmation": .bool(true)
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    func testRunShortcutErrorReturnsErrorResult() async throws {
        provider.runShortcutError = ShortcutsError.shortcutNotFound("Send Report")

        let handler = try XCTUnwrap(handlers["run_shortcut"])
        let args: [String: JSONValue] = [
            "name": .string("Send Report"),
            "confirmation": .bool(true)
        ]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
        let text = result.content.first?.text ?? ""
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - get_shortcut_details

    func testGetShortcutDetailsCallsProviderWithName() async throws {
        provider.getShortcutDetailsResult = [
            "name": "Send Daily Report",
            "folder": "Work",
            "actions": 5
        ]

        let handler = try XCTUnwrap(handlers["get_shortcut_details"])
        let args: [String: JSONValue] = ["name": .string("Send Daily Report")]
        _ = try await handler.handle(arguments: args)

        XCTAssertTrue(provider.getShortcutDetailsCalled)
    }

    func testGetShortcutDetailsReturnsFormattedText() async throws {
        provider.getShortcutDetailsResult = [
            "name": "Send Daily Report",
            "folder": "Work",
            "actions": 5
        ]

        let handler = try XCTUnwrap(handlers["get_shortcut_details"])
        let args: [String: JSONValue] = ["name": .string("Send Daily Report")]
        let result = try await handler.handle(arguments: args)

        XCTAssertFalse(result.isError ?? false)
        let text = result.content.first?.text ?? ""
        XCTAssertTrue(text.contains("Send Daily Report"))
    }

    func testGetShortcutDetailsMissingNameReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["get_shortcut_details"])
        let result = try await handler.handle(arguments: nil)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.getShortcutDetailsCalled)
    }

    func testGetShortcutDetailsMissingNameArgReturnsError() async throws {
        let handler = try XCTUnwrap(handlers["get_shortcut_details"])
        let args: [String: JSONValue] = [:]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(provider.getShortcutDetailsCalled)
    }

    func testGetShortcutDetailsErrorReturnsErrorResult() async throws {
        provider.getShortcutDetailsError = ShortcutsError.shortcutNotFound("Unknown")

        let handler = try XCTUnwrap(handlers["get_shortcut_details"])
        let args: [String: JSONValue] = ["name": .string("Unknown")]
        let result = try await handler.handle(arguments: args)

        XCTAssertEqual(result.isError, true)
    }
}

// MARK: - ShortcutsBridge Tests

final class ShortcutsBridgeTests: XCTestCase {

    var mockShell: MockShellExecutor!
    var bridge: ShortcutsBridge!

    override func setUp() {
        super.setUp()
        mockShell = MockShellExecutor()
        bridge = ShortcutsBridge(shell: mockShell)
    }

    // MARK: - listShortcuts

    func testListShortcutsExecutesCorrectCommand() async throws {
        mockShell.resultToReturn = ""

        _ = try await bridge.listShortcuts()

        XCTAssertEqual(mockShell.capturedCommand, "/usr/bin/shortcuts")
        XCTAssertEqual(mockShell.capturedArguments, ["list"])
    }

    func testListShortcutsParsesOutputLines() async throws {
        mockShell.resultToReturn = "Send Daily Report\nMorning Routine\nEvening Summary"

        let result = try await bridge.listShortcuts()

        XCTAssertEqual(result.count, 3)
    }

    func testListShortcutsReturnsNameForEachEntry() async throws {
        mockShell.resultToReturn = "My Shortcut\nAnother One"

        let result = try await bridge.listShortcuts()

        let names = result.compactMap { $0["name"] as? String }
        XCTAssertTrue(names.contains("My Shortcut"))
        XCTAssertTrue(names.contains("Another One"))
    }

    func testListShortcutsEmptyOutputReturnsEmptyArray() async throws {
        mockShell.resultToReturn = ""

        let result = try await bridge.listShortcuts()

        XCTAssertEqual(result.count, 0)
    }

    func testListShortcutsNonZeroExitCodeThrows() async throws {
        mockShell.errorToThrow = ShellError.nonZeroExit(1, "Error: something went wrong")

        do {
            _ = try await bridge.listShortcuts()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ShortcutsError)
        }
    }

    func testListShortcutsSkipsBlankLines() async throws {
        mockShell.resultToReturn = "Shortcut One\n\n\nShortcut Two\n"

        let result = try await bridge.listShortcuts()

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - runShortcut

    func testRunShortcutExecutesCorrectCommand() async throws {
        mockShell.resultToReturn = "Done"

        _ = try await bridge.runShortcut(name: "Send Report", input: nil, confirmation: true)

        XCTAssertEqual(mockShell.capturedCommand, "/usr/bin/shortcuts")
        XCTAssertTrue(mockShell.capturedArguments.contains("run"))
        XCTAssertTrue(mockShell.capturedArguments.contains("Send Report"))
    }

    func testRunShortcutPassesInputFlag() async throws {
        mockShell.resultToReturn = ""

        _ = try await bridge.runShortcut(name: "Process", input: "hello", confirmation: true)

        XCTAssertTrue(mockShell.capturedArguments.contains("--input-path"))
    }

    func testRunShortcutNoInputOmitsInputFlag() async throws {
        mockShell.resultToReturn = ""

        _ = try await bridge.runShortcut(name: "No Input Shortcut", input: nil, confirmation: true)

        XCTAssertFalse(mockShell.capturedArguments.contains("--input-path"))
        XCTAssertFalse(mockShell.capturedArguments.contains("-i"))
    }

    func testRunShortcutReturnsOutputInResult() async throws {
        mockShell.resultToReturn = "Report sent"

        let result = try await bridge.runShortcut(name: "Send Report", input: nil, confirmation: true)

        XCTAssertEqual(result["output"] as? String, "Report sent")
    }

    func testRunShortcutNonZeroExitCodeThrows() async throws {
        mockShell.errorToThrow = ShellError.nonZeroExit(1, "Shortcut not found")

        do {
            _ = try await bridge.runShortcut(name: "Nonexistent", input: nil, confirmation: true)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ShortcutsError)
        }
    }

    func testRunShortcutSuccessResultContainsSuccessFlag() async throws {
        mockShell.resultToReturn = ""

        let result = try await bridge.runShortcut(name: "My Shortcut", input: nil, confirmation: true)

        let success = result["success"] as? Bool
        XCTAssertEqual(success, true)
    }

    // MARK: - getShortcutDetails

    func testGetShortcutDetailsExecutesCorrectCommand() async throws {
        mockShell.resultToReturn = "Send Daily Report\nMorning Routine"

        _ = try await bridge.getShortcutDetails(name: "Send Daily Report")

        XCTAssertEqual(mockShell.capturedCommand, "/usr/bin/shortcuts")
        XCTAssertEqual(mockShell.capturedArguments, ["list"])
    }

    func testGetShortcutDetailsReturnsNameInResult() async throws {
        mockShell.resultToReturn = "Send Daily Report\nMorning Routine"

        let result = try await bridge.getShortcutDetails(name: "Send Daily Report")

        XCTAssertEqual(result["name"] as? String, "Send Daily Report")
    }

    func testGetShortcutDetailsNotFoundThrows() async throws {
        mockShell.resultToReturn = "Morning Routine\nEvening Summary"

        do {
            _ = try await bridge.getShortcutDetails(name: "Nonexistent Shortcut")
            XCTFail("Expected ShortcutsError.shortcutNotFound to be thrown")
        } catch let error as ShortcutsError {
            if case .shortcutNotFound(let name) = error {
                XCTAssertEqual(name, "Nonexistent Shortcut")
            } else {
                XCTFail("Expected shortcutNotFound error, got \(error)")
            }
        }
    }

    func testGetShortcutDetailsCommandFailureThrows() async throws {
        mockShell.errorToThrow = ShellError.nonZeroExit(1, "Permission denied")

        do {
            _ = try await bridge.getShortcutDetails(name: "Any Shortcut")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ShortcutsError)
        }
    }
}
