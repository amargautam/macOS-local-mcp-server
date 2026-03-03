import Foundation

/// Shared utility functions for tool handlers.
/// Consolidates serialization and date parsing used across all tool modules.
enum ToolHelpers {

    // MARK: - JSON Serialization

    /// Encode an array of dictionaries to a JSON string for MCPToolResult.
    static func encodeArray(_ array: [[String: Any]]) throws -> String {
        let jsonValue = JSONValue.from(arrayOfDictionaries: array)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(jsonValue)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Encode a single dictionary to a JSON string for MCPToolResult.
    static func encodeDictionary(_ dict: [String: Any]) throws -> String {
        let jsonValue = JSONValue.from(dictionary: dict)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(jsonValue)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Date Parsing

    /// Parse an ISO 8601 date string with fractional seconds support.
    /// Tries fractional seconds first, then falls back to standard format.
    static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: string)
    }

    // MARK: - Argument Extraction

    /// Extract an optional string parameter.
    static func optionalString(_ key: String, from arguments: [String: JSONValue]?) -> String? {
        guard let args = arguments, case .string(let value) = args[key] else { return nil }
        return value
    }

    /// Extract an optional integer parameter.
    static func optionalInt(_ key: String, from arguments: [String: JSONValue]?) -> Int? {
        guard let args = arguments, case .int(let value) = args[key] else { return nil }
        return value
    }

    /// Extract an optional boolean parameter.
    static func optionalBool(_ key: String, from arguments: [String: JSONValue]?) -> Bool? {
        guard let args = arguments, case .bool(let value) = args[key] else { return nil }
        return value
    }

    /// Extract an optional array of strings parameter.
    static func optionalStringArray(_ key: String, from arguments: [String: JSONValue]?) -> [String]? {
        guard let args = arguments, case .array(let items) = args[key] else { return nil }
        return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
    }
}
