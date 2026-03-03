import Foundation

/// Implements SafariProviding by executing AppleScript via a ScriptExecuting instance.
final class SafariBridge: SafariProviding {

    private let executor: ScriptExecuting

    init(executor: ScriptExecuting = AppleScriptBridge()) {
        self.executor = executor
    }

    // MARK: - listOpenTabs

    func listOpenTabs() async throws -> [[String: Any]] {
        let script = """
        tell application "Safari"
            set tabList to {}
            set winIdx to 0
            repeat with w in windows
                set winIdx to winIdx + 1
                set tabIdx to 0
                repeat with t in tabs of w
                    set tabIdx to tabIdx + 1
                    set end of tabList to {windowIndex:winIdx, tabIndex:tabIdx, title:(name of t), url:(URL of t)}
                end repeat
            end repeat
        end tell
        set output to "["
        set isFirst to true
        repeat with entry in tabList
            if not isFirst then set output to output & ","
            set isFirst to false
            set output to output & "{\\\"windowIndex\\\":" & (windowIndex of entry) & ",\\\"tabIndex\\\":" & (tabIndex of entry) & ",\\\"title\\\":\\\"" & (title of entry) & "\\\",\\\"url\\\":\\\"" & (url of entry) & "\\\"}"
        end repeat
        set output to output & "]"
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - listReadingList

    func listReadingList() async throws -> [[String: Any]] {
        let script = """
        tell application "Safari"
            set rlItems to reading list items
            set output to "["
            set isFirst to true
            repeat with item in rlItems
                if not isFirst then set output to output & ","
                set isFirst to false
                set itemTitle to title of item
                set itemURL to URL of item
                set output to output & "{\\\"title\\\":\\\"" & itemTitle & "\\\",\\\"url\\\":\\\"" & itemURL & "\\\"}"
            end repeat
            set output to output & "]"
        end tell
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - searchBookmarks

    func searchBookmarks(query: String) async throws -> [[String: Any]] {
        let escapedQuery = escapeForAppleScript(query)
        let script = """
        tell application "Safari"
            set matchedBookmarks to {}
            set searchQuery to "\(escapedQuery)"
            set allBookmarks to every bookmark
            repeat with bm in allBookmarks
                set bmTitle to ""
                set bmURL to ""
                try
                    set bmTitle to name of bm
                    set bmURL to URL of bm
                end try
                if bmTitle contains searchQuery or bmURL contains searchQuery then
                    set end of matchedBookmarks to {title:bmTitle, url:bmURL}
                end if
            end repeat
            set output to "["
            set isFirst to true
            repeat with entry in matchedBookmarks
                if not isFirst then set output to output & ","
                set isFirst to false
                set output to output & "{\\\"title\\\":\\\"" & (title of entry) & "\\\",\\\"url\\\":\\\"" & (url of entry) & "\\\"}"
            end repeat
            set output to output & "]"
        end tell
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - searchHistory

    func searchHistory(query: String, daysBack: Int?) async throws -> [[String: Any]] {
        let escapedQuery = escapeForSQL(query)
        let days = min(daysBack ?? 7, 90)
        let script = """
        -- Safari history is stored in ~/Library/Safari/History.db (SQLite)
        -- Use shell to query it since AppleScript cannot access SQLite directly
        set dbPath to (POSIX path of (path to home folder)) & "Library/Safari/History.db"
        set searchQuery to "\(escapeForAppleScript(query))"
        set sqlQuery to "\(escapedQuery)"
        set numDays to \(days)
        set secondsBack to numDays * 86400
        set shellCmd to "sqlite3 " & quoted form of dbPath & " \\"SELECT title, url, datetime(visit_time + 978307200, 'unixepoch') as visit_date FROM history_visits JOIN history_items ON history_visits.history_item = history_items.id WHERE (title LIKE '%" & sqlQuery & "%' OR url LIKE '%" & sqlQuery & "%') AND visit_time > (strftime('%s', 'now') - 978307200 - " & secondsBack & ") ORDER BY visit_time DESC LIMIT 50\\""
        set rawResult to do shell script shellCmd
        -- Parse pipe-separated rows into JSON
        set output to "["
        set isFirst to true
        set AppleScript's text item delimiters to linefeed
        set rows to every text item of rawResult
        set AppleScript's text item delimiters to ""
        repeat with row in rows
            if row is not "" then
                set AppleScript's text item delimiters to "|"
                set cols to every text item of row
                set AppleScript's text item delimiters to ""
                if (count of cols) >= 2 then
                    set colTitle to item 1 of cols
                    set colURL to item 2 of cols
                    set colDate to ""
                    if (count of cols) >= 3 then set colDate to item 3 of cols
                    if not isFirst then set output to output & ","
                    set isFirst to false
                    set output to output & "{\\\"title\\\":\\\"" & colTitle & "\\\",\\\"url\\\":\\\"" & colURL & "\\\",\\\"visitDate\\\":\\\"" & colDate & "\\\"}"
                end if
            end if
        end repeat
        set output to output & "]"
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - closeTab

    func closeTab(index: Int?, url: String?, confirmation: Bool) async throws -> [String: Any] {
        let script: String
        if let idx = index {
            script = """
            tell application "Safari"
                set w to front window
                set tabCount to count of tabs of w
                if \(idx) > tabCount then
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"Tab index \(idx) out of range (window has \\" & tabCount & \\" tabs)\\\"}"
                end if
                close tab \(idx) of w
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Closed tab at index \(idx)\\\"}"
            """
        } else if let targetURL = url {
            let escapedURL = escapeForAppleScript(targetURL)
            script = """
            tell application "Safari"
                set closedCount to 0
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "\(escapedURL)" then
                            close t
                            set closedCount to closedCount + 1
                            exit repeat
                        end if
                    end repeat
                end repeat
                if closedCount > 0 then
                    return "{\\\"success\\\":true,\\\"message\\\":\\\"Closed tab matching URL\\\"}"
                else
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"No tab found matching URL\\\"}"
                end if
            end tell
            """
        } else {
            script = """
            tell application "Safari"
                close current tab of front window
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Closed active tab\\\"}"
            """
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - addToReadingList

    func addToReadingList(url: String, title: String?) async throws -> [String: Any] {
        let escapedURL = escapeForAppleScript(url)
        let script: String
        if let t = title {
            let escapedTitle = escapeForAppleScript(t)
            script = """
            tell application "Safari"
                add reading list item "\(escapedURL)" with title "\(escapedTitle)"
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Added to reading list\\\"}"
            """
        } else {
            script = """
            tell application "Safari"
                add reading list item "\(escapedURL)"
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Added to reading list\\\"}"
            """
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - addBookmark

    func addBookmark(url: String, title: String, folderName: String?) async throws -> [String: Any] {
        let escapedURL = escapeForAppleScript(url)
        let escapedTitle = escapeForAppleScript(title)
        let script: String
        if let folder = folderName {
            let escapedFolder = escapeForAppleScript(folder)
            script = """
            tell application "Safari"
                set targetFolder to missing value
                repeat with f in bookmark folders
                    if name of f is "\(escapedFolder)" then
                        set targetFolder to f
                        exit repeat
                    end if
                end repeat
                if targetFolder is missing value then
                    make new bookmark at end of bookmark folders with properties {name:"\(escapedTitle)", URL:"\(escapedURL)"}
                else
                    make new bookmark at end of targetFolder with properties {name:"\(escapedTitle)", URL:"\(escapedURL)"}
                end if
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Bookmark added\\\"}"
            """
        } else {
            script = """
            tell application "Safari"
                make new bookmark at end of bookmark folders with properties {name:"\(escapedTitle)", URL:"\(escapedURL)"}
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Bookmark added\\\"}"
            """
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - deleteBookmark

    func deleteBookmark(title: String?, url: String?, confirmation: Bool) async throws -> [String: Any] {
        let script: String
        if let t = title {
            let escapedTitle = escapeForAppleScript(t)
            script = """
            tell application "Safari"
                set deletedCount to 0
                set allBookmarks to every bookmark
                repeat with bm in allBookmarks
                    try
                        if name of bm is "\(escapedTitle)" then
                            delete bm
                            set deletedCount to deletedCount + 1
                        end if
                    end try
                end repeat
                if deletedCount > 0 then
                    return "{\\\"success\\\":true,\\\"message\\\":\\\"Deleted " & deletedCount & " bookmark(s) matching title\\\"}"
                else
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"No bookmark found with that title\\\"}"
                end if
            end tell
            """
        } else if let u = url {
            let escapedURL = escapeForAppleScript(u)
            script = """
            tell application "Safari"
                set deletedCount to 0
                set allBookmarks to every bookmark
                repeat with bm in allBookmarks
                    try
                        if URL of bm is "\(escapedURL)" then
                            delete bm
                            set deletedCount to deletedCount + 1
                        end if
                    end try
                end repeat
                if deletedCount > 0 then
                    return "{\\\"success\\\":true,\\\"message\\\":\\\"Deleted " & deletedCount & " bookmark(s) matching URL\\\"}"
                else
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"No bookmark found with that URL\\\"}"
                end if
            end tell
            """
        } else {
            return ["success": false, "message": "Either title or url must be provided"]
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - listBookmarkFolders

    func listBookmarkFolders() async throws -> [[String: Any]] {
        let script = """
        tell application "Safari"
            set folderList to {}
            repeat with f in bookmark folders
                set end of folderList to name of f
            end repeat
            set output to "["
            set isFirst to true
            repeat with folderName in folderList
                if not isFirst then set output to output & ","
                set isFirst to false
                set output to output & "{\\\"name\\\":\\\"" & folderName & "\\\"}"
            end repeat
            set output to output & "]"
        end tell
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - createBookmarkFolder

    func createBookmarkFolder(name: String) async throws -> [String: Any] {
        let escapedName = escapeForAppleScript(name)
        let script = """
        tell application "Safari"
            make new bookmark folder at end of bookmark folders with properties {name:"\(escapedName)"}
        end tell
        return "{\\\"success\\\":true,\\\"name\\\":\\\"" & "\(escapedName)" & "\\\"}"
        """
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - findDuplicateTabs

    func findDuplicateTabs() async throws -> [[String: Any]] {
        let script = """
        tell application "Safari"
            set tabList to {}
            set winIdx to 0
            repeat with w in windows
                set winIdx to winIdx + 1
                set tabIdx to 0
                repeat with t in tabs of w
                    set tabIdx to tabIdx + 1
                    set end of tabList to {windowIndex:winIdx, tabIndex:tabIdx, tabTitle:(name of t), tabURL:(URL of t)}
                end repeat
            end repeat
        end tell
        -- Group by URL and find duplicates
        set urlGroups to {}
        set urlList to {}
        repeat with entry in tabList
            set eURL to tabURL of entry
            set found to false
            set groupIdx to 0
            repeat with i from 1 to count of urlGroups
                if (item 1 of item i of urlGroups) is eURL then
                    set found to true
                    set groupIdx to i
                    exit repeat
                end if
            end repeat
            if found then
                set existingGroup to item groupIdx of urlGroups
                set end of existingGroup to entry
                set item groupIdx of urlGroups to existingGroup
            else
                set end of urlGroups to {eURL, entry}
            end if
        end repeat
        -- Build output for groups with count > 1
        set output to "["
        set isFirst to true
        repeat with grp in urlGroups
            set grpURL to item 1 of grp
            set grpCount to (count of grp) - 1
            if grpCount > 1 then
                if not isFirst then set output to output & ","
                set isFirst to false
                set output to output & "{\\\"url\\\":\\\"" & grpURL & "\\\",\\\"count\\\":" & grpCount & "}"
            end if
        end repeat
        set output to output & "]"
        return output
        """
        let raw = try executor.executeScript(script)
        return try parseArrayOfDicts(raw)
    }

    // MARK: - closeTabsMatching

    func closeTabsMatching(pattern: String, confirmation: Bool) async throws -> [String: Any] {
        let escapedPattern = escapeForAppleScript(pattern)
        let script = """
        tell application "Safari"
            set closedCount to 0
            repeat with w in windows
                set tabsToClose to {}
                repeat with t in tabs of w
                    if URL of t contains "\(escapedPattern)" then
                        set end of tabsToClose to t
                    end if
                end repeat
                repeat with t in tabsToClose
                    close t
                    set closedCount to closedCount + 1
                end repeat
            end repeat
            return "{\\\"success\\\":true,\\\"closedCount\\\":" & closedCount & ",\\\"message\\\":\\\"Closed " & closedCount & " tab(s) matching pattern\\\"}"
        end tell
        """
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - getTabContent

    func getTabContent(index: Int?, url: String?) async throws -> [String: Any] {
        let script: String
        if let idx = index {
            script = """
            tell application "Safari"
                set w to front window
                set t to tab \(idx) of w
                set tabTitle to name of t
                set tabURL to URL of t
                set tabContent to do JavaScript "document.body.innerText" in t
            end tell
            return "{\\\"title\\\":\\\"" & tabTitle & "\\\",\\\"url\\\":\\\"" & tabURL & "\\\",\\\"content\\\":\\\"" & tabContent & "\\\"}"
            """
        } else if let targetURL = url {
            let escapedURL = escapeForAppleScript(targetURL)
            script = """
            tell application "Safari"
                set tabTitle to ""
                set tabURL to ""
                set tabContent to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "\(escapedURL)" then
                            set tabTitle to name of t
                            set tabURL to URL of t
                            set tabContent to do JavaScript "document.body.innerText" in t
                            exit repeat
                        end if
                    end repeat
                    if tabURL is not "" then exit repeat
                end repeat
                if tabURL is "" then
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"No tab found matching URL\\\"}"
                end if
            end tell
            return "{\\\"title\\\":\\\"" & tabTitle & "\\\",\\\"url\\\":\\\"" & tabURL & "\\\",\\\"content\\\":\\\"" & tabContent & "\\\"}"
            """
        } else {
            return ["success": false, "message": "Either index or url must be provided"]
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - newTab

    func newTab(url: String) async throws -> [String: Any] {
        let escapedURL = escapeForAppleScript(url)
        let script = """
        tell application "Safari"
            make new document with properties {URL:"\(escapedURL)"}
        end tell
        return "{\\\"success\\\":true,\\\"url\\\":\\\"" & "\(escapedURL)" & "\\\"}"
        """
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - reloadTab

    func reloadTab(index: Int?, url: String?) async throws -> [String: Any] {
        let script: String
        if let idx = index {
            script = """
            tell application "Safari"
                set w to front window
                set t to tab \(idx) of w
                do JavaScript "location.reload()" in t
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Reloaded tab at index \(idx)\\\"}"
            """
        } else if let targetURL = url {
            let escapedURL = escapeForAppleScript(targetURL)
            script = """
            tell application "Safari"
                set reloaded to false
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "\(escapedURL)" then
                            do JavaScript "location.reload()" in t
                            set reloaded to true
                            exit repeat
                        end if
                    end repeat
                    if reloaded then exit repeat
                end repeat
                if reloaded then
                    return "{\\\"success\\\":true,\\\"message\\\":\\\"Reloaded tab matching URL\\\"}"
                else
                    return "{\\\"success\\\":false,\\\"message\\\":\\\"No tab found matching URL\\\"}"
                end if
            end tell
            """
        } else {
            script = """
            tell application "Safari"
                do JavaScript "location.reload()" in current tab of front window
            end tell
            return "{\\\"success\\\":true,\\\"message\\\":\\\"Reloaded active tab\\\"}"
            """
        }
        let raw = try executor.executeScript(script)
        return try parseSingleDict(raw)
    }

    // MARK: - Private Helpers

    /// Escapes a string for safe embedding in AppleScript string literals.
    private func escapeForAppleScript(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    /// Escapes a string for safe embedding in a SQL LIKE clause (single-quoted).
    private func escapeForSQL(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "'", with: "''")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    /// Parse a JSON array string (possibly returned as AppleScript output) into [[String: Any]].
    private func parseArrayOfDicts(_ raw: String) throws -> [[String: Any]] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "[]" {
            return []
        }
        guard let data = trimmed.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // If it's not JSON, treat it as empty (AppleScript sometimes returns "missing value")
            return []
        }
        return parsed
    }

    /// Parse a JSON object string into [String: Any].
    private func parseSingleDict(_ raw: String) throws -> [String: Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "{}" {
            return [:]
        }
        guard let data = trimmed.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return parsed
    }
}
