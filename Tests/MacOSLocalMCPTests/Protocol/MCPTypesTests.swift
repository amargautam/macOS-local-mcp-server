import XCTest
@testable import MacOSLocalMCP

final class MCPTypesTests: XCTestCase {

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // MARK: - JSONValue Encoding/Decoding

    func testJSONValueString() throws {
        let value = JSONValue.string("hello")
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueInt() throws {
        let value = JSONValue.int(42)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueDouble() throws {
        let value = JSONValue.double(3.14)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueBool() throws {
        let value = JSONValue.bool(true)
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueNull() throws {
        let value = JSONValue.null
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueArray() throws {
        let value = JSONValue.array([.string("a"), .int(1), .bool(true)])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueObject() throws {
        let value = JSONValue.object(["key": .string("value"), "num": .int(42)])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testJSONValueNestedObjectAndArray() throws {
        let value = JSONValue.object([
            "items": .array([.object(["id": .int(1), "name": .string("test")])])
        ])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    // MARK: - JSONValue Helper Methods

    func testObjectValue() {
        let value = JSONValue.object(["key": .string("value")])
        XCTAssertNotNil(value.objectValue)
        XCTAssertEqual(value.objectValue?["key"], .string("value"))
    }

    func testObjectValueOnNonObject() {
        XCTAssertNil(JSONValue.string("hello").objectValue)
        XCTAssertNil(JSONValue.int(1).objectValue)
        XCTAssertNil(JSONValue.array([]).objectValue)
    }

    func testArrayValue() {
        let value = JSONValue.array([.int(1), .int(2)])
        XCTAssertEqual(value.arrayValue?.count, 2)
    }

    func testArrayValueOnNonArray() {
        XCTAssertNil(JSONValue.string("hello").arrayValue)
        XCTAssertNil(JSONValue.object([:]).arrayValue)
    }

    func testStringValueForKey() {
        let value = JSONValue.object(["name": .string("test")])
        XCTAssertEqual(value.stringValue(forKey: "name"), "test")
        XCTAssertNil(value.stringValue(forKey: "missing"))
    }

    func testIntValueForKey() {
        let value = JSONValue.object(["count": .int(5)])
        XCTAssertEqual(value.intValue(forKey: "count"), 5)
        XCTAssertNil(value.intValue(forKey: "missing"))
    }

    func testBoolValueForKey() {
        let value = JSONValue.object(["active": .bool(true)])
        XCTAssertEqual(value.boolValue(forKey: "active"), true)
        XCTAssertNil(value.boolValue(forKey: "missing"))
    }

    func testToDictionary() {
        let value = JSONValue.object(["key": .string("val")])
        let dict = value.toDictionary()
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["key"], .string("val"))
    }

    func testToDictionaryOnNonObject() {
        XCTAssertNil(JSONValue.string("test").toDictionary())
    }

    func testFromDictionary() {
        let dict: [String: Any] = ["name": "test", "count": 5]
        let value = JSONValue.from(dictionary: dict)
        XCTAssertNotNil(value.objectValue)
        XCTAssertEqual(value.stringValue(forKey: "name"), "test")
    }

    func testFromAnyTypes() {
        XCTAssertEqual(JSONValue.from(any: "hello"), .string("hello"))
        XCTAssertEqual(JSONValue.from(any: 42), .int(42))
        XCTAssertEqual(JSONValue.from(any: true), .bool(true))
        XCTAssertEqual(JSONValue.from(any: 3.14), .double(3.14))
    }

    func testFromArrayOfDictionaries() {
        let arr: [[String: Any]] = [["id": 1], ["id": 2]]
        let value = JSONValue.from(arrayOfDictionaries: arr)
        XCTAssertEqual(value.arrayValue?.count, 2)
    }

    // MARK: - JSONRPCId

    func testJSONRPCIdInt() throws {
        let id = JSONRPCId.int(1)
        let data = try encoder.encode(id)
        let decoded = try decoder.decode(JSONRPCId.self, from: data)
        XCTAssertEqual(decoded, id)
    }

    func testJSONRPCIdString() throws {
        let id = JSONRPCId.string("abc-123")
        let data = try encoder.encode(id)
        let decoded = try decoder.decode(JSONRPCId.self, from: data)
        XCTAssertEqual(decoded, id)
    }

    func testJSONRPCIdEquality() {
        XCTAssertEqual(JSONRPCId.int(1), JSONRPCId.int(1))
        XCTAssertNotEqual(JSONRPCId.int(1), JSONRPCId.int(2))
        XCTAssertEqual(JSONRPCId.string("a"), JSONRPCId.string("a"))
        XCTAssertNotEqual(JSONRPCId.int(1), JSONRPCId.string("1"))
    }

    // MARK: - JSONRPCRequest

    func testJSONRPCRequestDecode() throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}
        """.data(using: .utf8)!
        let request = try decoder.decode(JSONRPCRequest.self, from: json)
        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.id, .int(1))
        XCTAssertEqual(request.method, "initialize")
        XCTAssertNotNil(request.params)
    }

    func testJSONRPCRequestWithoutParams() throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"method":"test"}
        """.data(using: .utf8)!
        let request = try decoder.decode(JSONRPCRequest.self, from: json)
        XCTAssertEqual(request.method, "test")
        XCTAssertNil(request.params)
    }

    func testJSONRPCRequestWithStringId() throws {
        let json = """
        {"jsonrpc":"2.0","id":"req-1","method":"test"}
        """.data(using: .utf8)!
        let request = try decoder.decode(JSONRPCRequest.self, from: json)
        XCTAssertEqual(request.id, .string("req-1"))
    }

    func testJSONRPCRequestEncode() throws {
        let request = JSONRPCRequest(id: .int(1), method: "test")
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(JSONRPCRequest.self, from: data)
        XCTAssertEqual(decoded.method, "test")
        XCTAssertEqual(decoded.jsonrpc, "2.0")
    }

    // MARK: - JSONRPCResponse

    func testJSONRPCResponseSuccess() throws {
        let response = JSONRPCResponse(id: .int(1), result: .string("ok"))
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(JSONRPCResponse.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.result, .string("ok"))
        XCTAssertNil(decoded.error)
    }

    func testJSONRPCResponseError() throws {
        let error = JSONRPCError(code: .methodNotFound, message: "Not found")
        let response = JSONRPCResponse(id: .int(1), error: error)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(JSONRPCResponse.self, from: data)
        XCTAssertNil(decoded.result)
        XCTAssertNotNil(decoded.error)
        XCTAssertEqual(decoded.error?.code, MCPErrorCode.methodNotFound.rawValue)
        XCTAssertEqual(decoded.error?.message, "Not found")
    }

    func testJSONRPCErrorWithData() throws {
        let error = JSONRPCError(code: .internalError, message: "err", data: .string("details"))
        let data = try encoder.encode(error)
        let decoded = try decoder.decode(JSONRPCError.self, from: data)
        XCTAssertEqual(decoded.data, .string("details"))
    }

    // MARK: - MCPToolResult

    func testMCPToolResultText() {
        let result = MCPToolResult.text("hello")
        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0].type, "text")
        XCTAssertEqual(result.content[0].text, "hello")
        XCTAssertNil(result.isError)
    }

    func testMCPToolResultError() {
        let result = MCPToolResult.error("bad")
        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0].text, "bad")
        XCTAssertEqual(result.isError, true)
    }

    func testMCPToolResultEncodeDecode() throws {
        let result = MCPToolResult.text("test")
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(MCPToolResult.self, from: data)
        XCTAssertEqual(decoded.content.first?.text, "test")
    }

    // MARK: - MCPErrorCode

    func testMCPErrorCodes() {
        XCTAssertEqual(MCPErrorCode.parseError.rawValue, -32700)
        XCTAssertEqual(MCPErrorCode.invalidRequest.rawValue, -32600)
        XCTAssertEqual(MCPErrorCode.methodNotFound.rawValue, -32601)
        XCTAssertEqual(MCPErrorCode.invalidParams.rawValue, -32602)
        XCTAssertEqual(MCPErrorCode.internalError.rawValue, -32603)
        XCTAssertEqual(MCPErrorCode.toolNotFound.rawValue, -31000)
        XCTAssertEqual(MCPErrorCode.toolDisabled.rawValue, -31001)
        XCTAssertEqual(MCPErrorCode.confirmationRequired.rawValue, -31002)
        XCTAssertEqual(MCPErrorCode.permissionDenied.rawValue, -31003)
    }

    // MARK: - MCPInitializeResult

    func testMCPInitializeResultRoundTrip() throws {
        let result = MCPInitializeResult(
            protocolVersion: "2024-11-05",
            capabilities: MCPServerCapabilities(tools: MCPToolsCapability(listChanged: true)),
            serverInfo: MCPServerInfo(name: "macOS Local MCP", version: "0.1.0")
        )
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(MCPInitializeResult.self, from: data)
        XCTAssertEqual(decoded.protocolVersion, "2024-11-05")
        XCTAssertEqual(decoded.serverInfo.name, "macOS Local MCP")
        XCTAssertEqual(decoded.serverInfo.version, "0.1.0")
        XCTAssertEqual(decoded.capabilities.tools?.listChanged, true)
    }

    // MARK: - MCPToolDefinition

    func testMCPToolDefinitionRoundTrip() throws {
        let tool = MCPToolDefinition(
            name: "test_tool",
            description: "A test tool",
            inputSchema: MCPToolInputSchema(
                type: "object",
                properties: ["query": MCPToolParameter(type: "string", description: "Search query")],
                required: ["query"]
            )
        )
        let data = try encoder.encode(tool)
        let decoded = try decoder.decode(MCPToolDefinition.self, from: data)
        XCTAssertEqual(decoded.name, "test_tool")
        XCTAssertEqual(decoded.description, "A test tool")
        XCTAssertEqual(decoded.inputSchema.type, "object")
        XCTAssertEqual(decoded.inputSchema.required, ["query"])
    }

    func testMCPToolParameterWithEnum() throws {
        let param = MCPToolParameter(type: "string", description: "Sort", enum: ["title", "date"])
        let data = try encoder.encode(param)
        let decoded = try decoder.decode(MCPToolParameter.self, from: data)
        XCTAssertEqual(decoded.enum, ["title", "date"])
    }

    func testMCPToolParameterWithItems() throws {
        let param = MCPToolParameter(type: "array", description: "Tags", items: MCPToolParameterItems(type: "string"))
        let data = try encoder.encode(param)
        let decoded = try decoder.decode(MCPToolParameter.self, from: data)
        XCTAssertEqual(decoded.items?.type, "string")
    }
}
