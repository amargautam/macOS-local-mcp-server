import Foundation

/// Handles all Finder and Spotlight MCP tool calls.
struct FinderTool {
    private let provider: FinderProviding

    init(provider: FinderProviding) {
        self.provider = provider
    }

    /// Creates and returns all Finder/Spotlight tool handlers.
    func createHandlers() -> [MCPToolHandler] {
        [
            spotlightSearchHandler(),
            spotlightSearchContentHandler(),
            getFileMetadataHandler(),
            setFinderTagsHandler(),
            listFinderTagsHandler(),
            getTaggedFilesHandler(),
        ]
    }

    // MARK: - Private handler factories

    private func spotlightSearchHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "spotlight_search") { [provider] arguments in
            guard let args = arguments,
                  case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }
            let kind: String? = {
                guard case .string(let v) = args["kind"] else { return nil }
                return v
            }()
            let directory: String? = {
                guard case .string(let v) = args["directory"] else { return nil }
                return v
            }()
            let maxResults: Int? = {
                guard case .int(let v) = args["max_results"] else { return nil }
                return v
            }()
            do {
                let results = try await provider.spotlightSearch(
                    query: query,
                    kind: kind,
                    directory: directory,
                    maxResults: maxResults
                )
                return try encodeArray(results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func spotlightSearchContentHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "spotlight_search_content") { [provider] arguments in
            guard let args = arguments,
                  case .string(let query) = args["query"] else {
                return .error("Missing required parameter: query")
            }
            let directory: String? = {
                guard case .string(let v) = args["directory"] else { return nil }
                return v
            }()
            let maxResults: Int? = {
                guard case .int(let v) = args["max_results"] else { return nil }
                return v
            }()
            do {
                let results = try await provider.spotlightSearchContent(
                    query: query,
                    directory: directory,
                    maxResults: maxResults
                )
                return try encodeArray(results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func getFileMetadataHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "get_file_metadata") { [provider] arguments in
            guard let args = arguments,
                  case .string(let path) = args["path"] else {
                return .error("Missing required parameter: path")
            }
            do {
                let result = try await provider.getFileMetadata(path: path)
                return try encodeObject(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func setFinderTagsHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "set_finder_tags") { [provider] arguments in
            guard let args = arguments,
                  case .string(let path) = args["path"] else {
                return .error("Missing required parameter: path")
            }
            guard let args = arguments,
                  case .array(let tagValues) = args["tags"] else {
                return .error("Missing required parameter: tags")
            }
            let tags: [String] = tagValues.compactMap {
                if case .string(let s) = $0 { return s } else { return nil }
            }
            do {
                let result = try await provider.setFinderTags(path: path, tags: tags)
                return try encodeObject(result)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func listFinderTagsHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "list_finder_tags") { [provider] _ in
            do {
                let results = try await provider.listFinderTags()
                return try encodeArray(results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    private func getTaggedFilesHandler() -> MCPToolHandler {
        ClosureToolHandler(toolName: "get_tagged_files") { [provider] arguments in
            guard let args = arguments,
                  case .string(let tag) = args["tag"] else {
                return .error("Missing required parameter: tag")
            }
            do {
                let results = try await provider.getTaggedFiles(tag: tag)
                return try encodeArray(results)
            } catch {
                return .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Serialisation helpers

    private func encodeArray(_ array: [[String: Any]]) throws -> MCPToolResult {
        let jsonValue = JSONValue.from(arrayOfDictionaries: array)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(jsonValue)
        let text = String(data: data, encoding: .utf8) ?? "[]"
        return .text(text)
    }

    private func encodeObject(_ dict: [String: Any]) throws -> MCPToolResult {
        let jsonValue = JSONValue.from(dictionary: dict)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(jsonValue)
        let text = String(data: data, encoding: .utf8) ?? "{}"
        return .text(text)
    }
}
