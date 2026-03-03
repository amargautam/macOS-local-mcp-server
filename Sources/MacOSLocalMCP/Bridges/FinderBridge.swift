import Foundation

/// Concrete implementation of `FinderProviding` that uses shell commands
/// (mdfind, mdls, xattr) to interact with macOS Spotlight and Finder.
final class FinderBridge: FinderProviding {

    private let shell: ShellCommandExecuting

    init(shell: ShellCommandExecuting = ProcessShellExecutor()) {
        self.shell = shell
    }

    // MARK: - spotlightSearch

    func spotlightSearch(
        query: String,
        kind: String?,
        directory: String?,
        maxResults: Int?
    ) async throws -> [[String: Any]] {
        var arguments: [String] = []

        // Restrict to a directory if provided
        if let directory = directory {
            arguments += ["-onlyin", directory]
        }

        // Build the Spotlight query with sanitized input
        let sanitizedQuery = FinderBridge.sanitizeSpotlightQuery(query)
        var spotlightQuery = sanitizedQuery
        if let kind = kind {
            let sanitizedKind = FinderBridge.sanitizeSpotlightQuery(kind)
            spotlightQuery = "\(sanitizedQuery) kMDItemKind == '*\(sanitizedKind)*'c"
        }
        arguments.append(spotlightQuery)

        let output = try shell.execute(command: "/usr/bin/mdfind", arguments: arguments)
        let paths = parsePathLines(output)
        let limited = applyLimit(paths, maxResults: maxResults)
        return limited.map { buildPathResult(path: $0) }
    }

    // MARK: - spotlightSearchContent

    func spotlightSearchContent(
        query: String,
        directory: String?,
        maxResults: Int?
    ) async throws -> [[String: Any]] {
        var arguments: [String] = []

        if let directory = directory {
            arguments += ["-onlyin", directory]
        }

        // Search within file content with sanitized input
        let sanitizedQuery = FinderBridge.sanitizeSpotlightQuery(query)
        let spotlightQuery = "kMDItemTextContent == '*\(sanitizedQuery)*'c"
        arguments.append(spotlightQuery)

        let output = try shell.execute(command: "/usr/bin/mdfind", arguments: arguments)
        let paths = parsePathLines(output)
        let limited = applyLimit(paths, maxResults: maxResults)
        return limited.map { buildPathResult(path: $0) }
    }

    // MARK: - getFileMetadata

    func getFileMetadata(path: String) async throws -> [String: Any] {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            throw FinderError.pathNotAllowed(resolved)
        }
        let output = try shell.execute(command: "/usr/bin/mdls", arguments: [resolved])
        var result = parseMdlsOutput(output)
        result["path"] = resolved
        return result
    }

    // MARK: - setFinderTags

    func setFinderTags(path: String, tags: [String]) async throws -> [String: Any] {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            throw FinderError.pathNotAllowed(resolved)
        }
        // Encode the plist value for com.apple.metadata:_kMDItemUserTags as binary plist.
        let plistData = try buildTagsPlist(tags: tags)

        // xattr -wx accepts hex-encoded data as the value argument.
        // Format: xattr -wx com.apple.metadata:_kMDItemUserTags <hexdata> <path>
        let hexEncoded = plistData.map { String(format: "%02x", $0) }.joined()

        _ = try shell.execute(
            command: "/usr/bin/xattr",
            arguments: ["-wx", "com.apple.metadata:_kMDItemUserTags", hexEncoded, path]
        )

        return ["success": true, "path": path, "tags": tags]
    }

    // MARK: - listFinderTags

    func listFinderTags() async throws -> [[String: Any]] {
        // Find all files that have any user tags
        let arguments = ["kMDItemUserTags == '*'"]
        let output = try shell.execute(command: "/usr/bin/mdfind", arguments: arguments)
        let paths = parsePathLines(output)
        // Return the files; callers can inspect tags per-file if needed
        return paths.map { buildPathResult(path: $0) }
    }

    // MARK: - getTaggedFiles

    func getTaggedFiles(tag: String) async throws -> [[String: Any]] {
        let sanitizedTag = FinderBridge.sanitizeSpotlightQuery(tag)
        let arguments = ["kMDItemUserTags == '\(sanitizedTag)'"]
        let output = try shell.execute(command: "/usr/bin/mdfind", arguments: arguments)
        let paths = parsePathLines(output)
        return paths.map { buildPathResult(path: $0) }
    }

    // MARK: - Private helpers

    private func parsePathLines(_ output: String) -> [String] {
        output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func applyLimit(_ paths: [String], maxResults: Int?) -> [String] {
        guard let limit = maxResults, limit < paths.count else { return paths }
        return Array(paths.prefix(limit))
    }

    private func buildPathResult(path: String) -> [String: Any] {
        let url = URL(fileURLWithPath: path)
        return [
            "path": path,
            "name": url.lastPathComponent,
        ]
    }

    /// Parse `mdls` key = value output into a dictionary.
    private func parseMdlsOutput(_ output: String) -> [String: Any] {
        var result: [String: Any] = [:]
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Lines are like: kMDItemDisplayName = "report.pdf"
            // or:             kMDItemFSSize     = 12345
            let parts = trimmed.components(separatedBy: " = ")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let rawValue = parts.dropFirst().joined(separator: " = ").trimmingCharacters(in: .whitespaces)

            // Try to parse as different types
            if rawValue == "(null)" {
                result[key] = NSNull()
            } else if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") {
                // String value
                let stripped = String(rawValue.dropFirst().dropLast())
                result[key] = stripped
            } else if let intValue = Int(rawValue) {
                result[key] = intValue
            } else if let doubleValue = Double(rawValue) {
                result[key] = doubleValue
            } else {
                result[key] = rawValue
            }
        }
        return result
    }

    /// Build a binary plist containing the tags array for com.apple.metadata:_kMDItemUserTags.
    private func buildTagsPlist(tags: [String]) throws -> Data {
        let plist = tags as NSArray
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    /// Resolve `~` and remove `..` components from a path.
    private func resolvePath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardized.path
    }

    /// Block access to sensitive system directories.
    private func isPathAllowed(_ path: String) -> Bool {
        let blocked = ["/System", "/Library", "/usr", "/bin", "/sbin", "/etc", "/var", "/private/etc"]
        for prefix in blocked {
            if path.hasPrefix(prefix) { return false }
        }
        return true
    }

    /// Sanitize a string for use in Spotlight query predicates.
    static func sanitizeSpotlightQuery(_ input: String) -> String {
        // Remove characters that could alter predicate logic
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .-_"))
        return String(input.unicodeScalars.filter { allowed.contains($0) })
    }
}

// MARK: - FinderError

enum FinderError: LocalizedError {
    case pathNotAllowed(String)

    var errorDescription: String? {
        switch self {
        case .pathNotAllowed:
            return "Access to this path is not allowed."
        }
    }
}
