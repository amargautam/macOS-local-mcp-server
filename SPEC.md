# Claude Code Prompt: macOS Local MCP Server + Admin App for macOS

## What We're Building

A local MCP server in Swift that bridges Claude Desktop/Cowork
to Apple apps and macOS system features. Plus a native SwiftUI
full-window macOS app to manage, monitor, and configure the server.

Two targets in one Swift package:
1. `macos-local-mcp` — headless MCP server binary (spawn-on-demand via stdio)
2. `macOS Local MCP` — full SwiftUI macOS app (Dock icon, proper window)

Everything runs locally. Zero network. Zero cloud. Zero telemetry.

---

## DEVELOPMENT METHODOLOGY

### Test-Driven Development (TDD)

For EVERY tool and every feature, follow this strict cycle:
1. RED: Write the test first. Define expected inputs,
   outputs, and edge cases. Test must fail.
2. GREEN: Write the minimum implementation to make
   the test pass.
3. REFACTOR: Clean up while keeping tests green.

DO NOT write any implementation code without a failing
test first. This is non-negotiable.

Run `swift test` after every implementation change.
Do not advance to the next phase until ALL tests in
the current phase are green.

### Multi-Agent Architecture

This project is built using Claude Code Agent Teams.
The architect (team lead) coordinates specialist agents.
Each agent must understand its role and boundaries.

**Agents and Responsibilities:**

| Agent | Role | Phases |
|-------|------|--------|
| architect | Team lead. Plans, delegates, reviews, coordinates. Does NOT implement modules. | All |
| protocol-engineer | MCP protocol, config, logging, ALL protocols and mocks | 0 |
| eventkit-engineer | Reminders, Calendar, Contacts (EventKit + Contacts.framework) | 1, 2 |
| applescript-engineer | Mail, Messages, Notes, Safari (AppleScript/JXA) | 4, 5, 6, 7 |
| system-engineer | Finder, Spotlight, Shortcuts (shell/CLI tools) | 3, 8 |
| ui-engineer | Entire SwiftUI admin app | 10 |
| code-reviewer | Reviews ALL code from all agents before phase is marked complete | All |
| security-reviewer | Audits codebase for injection, path traversal, permissions, data exposure | All |
| test-runner | Runs swift test, analyzes failures, verifies coverage and TDD compliance | All |
| integration-tester | Tests actual tool execution against real macOS apps | All |
| doc-writer | Maintains README.md, SPEC.md, PROGRESS.md, keeps docs in sync with code | All |

**Agent Rules:**
- Each agent works ONLY on their assigned modules
- Each agent conforms to protocols defined by the protocol-engineer
- Agents must NOT modify files outside their responsibility
  without explicit architect approval
- If an agent needs a change in another agent's module
  (e.g., a new protocol method), they request it through
  the architect, who delegates to the responsible agent
- Every agent writes tests FIRST (TDD), no exceptions

**Parallelization Rules:**
- Phases with no dependency can run in parallel
- Phase 0 MUST complete before any other phase starts
  (everyone depends on protocols and mocks)
- After Phase 0, these groups can run in parallel:
  - Group A: Phases 1, 2 (eventkit-engineer)
  - Group B: Phase 3 (system-engineer)
  - Group C: Phases 4, 5, 6, 7 (applescript-engineer)
  - Group D: Phases 8, 9 (system-engineer, after Phase 3)
- Phase 10 (admin app) can start once Phase 0 is done
  (it only depends on config/log file formats), but
  full testing requires server phases to be complete
- Phase 11 requires ALL other phases complete

**Communication Protocol:**
- Agents communicate through the architect (team lead)
- If an agent discovers a bug in shared code (protocols,
  mocks), they report to architect who delegates the fix
- Agents should include clear commit messages explaining
  what they built and which phase/module it belongs to

### Code Review Process

Every phase goes through mandatory code review BEFORE
being marked complete. The code-reviewer agent is a
dedicated specialist that reviews all code.

**Review Triggers:**
- After a specialist agent completes implementation
  and all tests pass
- After the architect merges work from parallel agents
- Before any phase is marked "done" in PROGRESS.md

**Review Checklist (code-reviewer must verify ALL):**

#### 1. TDD Compliance
- [ ] Tests exist for every public function
- [ ] Tests were written BEFORE implementation
  (check git log timestamps: test file committed
  before or in same commit as implementation)
- [ ] Minimum 3 tests per tool function:
  happy path, error case, edge case
- [ ] Test names are descriptive:
  `test_[function]_[scenario]_[expectedResult]()`
- [ ] No implementation code without corresponding tests

#### 2. Protocol Conformance
- [ ] Tool uses protocol-based DI (depends on protocol,
  not concrete bridge)
- [ ] Mock exists and conforms to same protocol
- [ ] Tool can be tested with mock (no hard dependency
  on real Apple frameworks in tests)

#### 3. Security
- [ ] Zero URLSession, URL(string:), NSURLConnection
  (grep the entire file)
- [ ] No external package imports beyond Swift stdlib
  and Apple frameworks
- [ ] Destructive actions require confirmation: true
- [ ] No data written to disk except approved locations
  (~/.macos-local-mcp/)
- [ ] No hardcoded paths, credentials, or personal data

#### 4. Error Handling
- [ ] Every tool handles permission denied gracefully
  (returns error with fix instructions, not a crash)
- [ ] Every tool handles empty results gracefully
  (returns empty array/object, not error)
- [ ] Every tool validates required parameters and
  returns descriptive errors for missing/invalid params
- [ ] No force unwraps (!) in production code
- [ ] No unhandled throws — all errors caught and
  converted to MCP error responses

#### 5. Code Quality
- [ ] Functions are under 50 lines (split if longer)
- [ ] No dead code, commented-out code, or TODOs
  left unresolved
- [ ] Naming follows Swift conventions (camelCase,
  descriptive, no abbreviations)
- [ ] No code duplication across modules — shared
  logic belongs in Bridges/
- [ ] File structure matches the project structure
  defined in this spec

#### 6. Integration Readiness
- [ ] Tool registers correctly in ToolDefinitions.swift
- [ ] Tool respects enabledModules config
  (disabled tool returns "module disabled" error)
- [ ] Activity logger records all tool invocations
- [ ] Integration test script exists and runs clean
  (creates test data, verifies, cleans up)

#### 7. Admin App (Phase 10 only)
- [ ] Native macOS controls only — no custom UI
- [ ] System fonts and colors only
- [ ] Dark mode works via system colors
- [ ] NavigationSplitView sidebar layout
- [ ] No web patterns (cards, shadows, gradients)
- [ ] All services have unit tests
- [ ] FSEvents-based live updates work
- [ ] Config changes propagate without server restart

**Review Process:**
1. Specialist agent completes work, all tests green
2. Architect spawns code-reviewer with context:
   "Review Phase [X] code. Files changed: [list].
   Run through the full review checklist."
3. Code-reviewer reads all changed files, runs
   the checklist, and produces a review report
4. If issues found:
   - Code-reviewer lists each issue with file, line,
     and specific fix needed
   - Architect delegates fixes to the original
     specialist agent
   - After fixes, code-reviewer re-reviews ONLY
     the changed items
5. If clean:
   - Code-reviewer approves: "Phase [X] APPROVED.
     All checklist items pass."
   - Architect marks phase complete in PROGRESS.md
   - Architect commits with message:
     "Phase [X] complete — reviewed and approved"

**Review Report Format:**
```
## Code Review: Phase [X] — [Module Name]

### Summary
- Files reviewed: [count]
- Tests verified: [count]
- Issues found: [count]
- Severity: [Critical / Warning / Nit]

### Issues
1. [CRITICAL] path/to/file.swift:42
   Description: Force unwrap on optional EKEventStore
   Fix: Use guard let with proper error return

2. [WARNING] path/to/test.swift:15
   Description: Missing edge case test for empty calendar
   Fix: Add test_listEvents_withNoEvents_returnsEmptyArray()

3. [NIT] path/to/file.swift:88
   Description: Function exceeds 50 lines
   Fix: Extract helper method for date range validation

### Verdict: NEEDS FIXES / APPROVED
```

### Progress Tracking

The architect maintains PROGRESS.md at the project root:

```markdown
# macOS Local MCP Build Progress

## Phase Status
| Phase | Module | Agent | Status | Review | Notes |
|-------|--------|-------|--------|--------|-------|
| 0 | Foundation | protocol-engineer | ✅ Done | ✅ Approved | |
| 1 | Reminders + Calendar | eventkit-engineer | 🔄 In Progress | — | |
| 2 | Contacts | eventkit-engineer | ⏳ Waiting | — | Blocked on Phase 0 |
| 3 | Finder + Spotlight | system-engineer | ⏳ Waiting | — | Can parallel with 1 |
| ... | ... | ... | ... | ... | ... |

## Current Sprint
- Active: Phase 1 (eventkit-engineer), Phase 3 (system-engineer)
- Next: Phase 2, Phase 4
- Blocked: None

## Review Log
- [date] Phase 0: Reviewed by code-reviewer. 2 issues found, fixed, re-reviewed. APPROVED.
- [date] Phase 1: ...

## Decisions & Notes
- [date] Decided to use JXA over plain AppleScript for Mail
  bridge due to better JSON output handling.
- [date] ...
```

---

## PART 1: MCP SERVER (macOS Local MCP binary)

### Architecture
- Pure Swift, compiled as a single macOS command-line binary
- MCP protocol over stdio transport (JSON-RPC over stdin/stdout)
- Native frameworks where possible (EventKit, Contacts.framework)
- NSAppleScript for apps without framework APIs
- Shell commands for CLI-based tools (mdfind, shortcuts, defaults)
- Zero network access — no URLSession, no external calls ever
- Protocol-based dependency injection for full testability
- Every external dependency accessed through a Swift protocol

### Lifecycle & Persistence

**Spawn-on-Demand (stdio transport):**
- MCP clients (Claude Desktop, etc.) launch a fresh process per session
- Server reads JSON-RPC from stdin, writes responses to stdout
- No persistent background process — exits after session ends
- Can write PID file to ~/.macos-local-mcp/server.pid during active sessions
- Writes heartbeat timestamp to ~/.macos-local-mcp/heartbeat
  every 30 seconds (admin app uses this to detect status)
- Logs startup, shutdown, crash recovery events

**LaunchAgent plist (com.amargautam.macos-local-mcp.plist):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.amargautam.macos-local-mcp</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/bin/macos-local-mcp</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityBackgroundIO</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.macos-local-mcp/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.macos-local-mcp/stderr.log</string>
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>1024</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MACOS_LOCAL_MCP_CONFIG</key>
        <string>$HOME/.macos-local-mcp/config.json</string>
    </dict>
</dict>
</plist>
```

**Config file (~/.macos-local-mcp/config.json):**
```json
{
  "logLevel": "normal",
  "logMaxSizeMB": 10,
  "enabledModules": {
    "reminders": {"read": true, "write": false},
    "calendar": {"read": true, "write": false},
    "mail": {"read": true, "write": false},
    "messages": {"read": true, "write": false},
    "notes": {"read": true, "write": false},
    "contacts": {"read": true, "write": false},
    "safari": {"read": true, "write": false},
    "finder": {"read": true, "write": false},
    "shortcuts": {"read": true, "write": false},
    "crossapp": {"read": true, "write": false}
  },
  "confirmationRequired": {
    "send_message": true,
    "send_draft": true,
    "delete_event": true,
    "delete_note": true,
    "close_tab": true,
    "run_shortcut": true,
    "complete_reminder": true,
    "bulk_decline_events": true,
    "bulk_archive_messages": true,
    "delete_bookmark": true,
    "close_tabs_matching": true,
    "delete_contact": true,
    "merge_contacts": true
  }
}
```

Default config is **read-only** for all modules. Each module supports
granular `{"read": bool, "write": bool}` access control. Legacy boolean
format (`"reminders": true`) is still supported for backward compatibility.

The server watches config.json via FSEvents and reloads
on change — no restart needed when admin app toggles settings.

### Tools to Implement

#### 1. Reminders (via EventKit)
- list_reminder_lists
- list_reminders (filter: due date range, completed,
  priority, list)
- create_reminder (title, notes, due date, priority,
  list, recurring rule, location trigger)
- update_reminder
- complete_reminder
- search_reminders (full-text across title and notes)
- move_reminder (move to a different list)
- bulk_move_reminders (move multiple reminders between lists)

#### 2. Calendar (via EventKit)
- list_calendars (all accounts, with colors and type)
- list_events (date range, calendar filter)
- create_event (title, start/end, location, calendar,
  notes, attendees, all-day, recurrence, alerts)
- update_event
- delete_event (require confirmation: true)
- check_availability (date range — return free/busy)
- search_events (keyword across title/notes/location)
- find_conflicts (find overlapping events in a date range)
- find_gaps (find free time slots between events)
- get_calendar_stats (event count and time statistics)
- bulk_decline_events (decline multiple events, require confirmation)

#### 3. Mail (via NSAppleScript → Mail.app)
- list_mailboxes
- list_recent_mail (last N, filter by mailbox,
  read/unread)
- search_mail (sender, subject, date range, body,
  mailbox, has_attachment)
- read_mail (full content + attachment names)
- create_draft (to, cc, bcc, subject, body as
  plain text or HTML)
- send_draft (require confirmation: true)
- move_message (to different mailbox)
- flag_message (flag/unflag, mark read/unread)
- find_unanswered_mail (find emails you haven't replied to)
- find_threads_awaiting_reply (find threads awaiting response)
- list_senders_by_frequency (rank senders by email count)
- bulk_archive_messages (archive multiple messages, require confirmation)

#### 4. Messages (via NSAppleScript → Messages.app)
- list_conversations (recent, with contact name,
  last message date, snippet)
- read_conversation (last N messages from contact)
- send_message (to phone/email, body —
  require confirmation: true)
- search_messages (keyword across conversations)

#### 5. Notes (via NSAppleScript → Notes.app)
- list_note_folders
- list_notes (folder filter, sort by modified date,
  limit/offset pagination — default limit 50)
- read_note (full content)
- create_note (title, body, folder)
- update_note (replace content)
- search_notes (full-text)
- delete_note (move to trash, require confirmation: true)
- append_to_note (append text to an existing note)
- find_stale_notes (find notes not modified within N days,
  limit/offset pagination — default limit 50)

#### 6. Contacts (via Contacts.framework)
- search_contacts (name, email, phone, company)
- get_contact (all phones, emails, addresses,
  birthday, company, createdAt, modifiedAt)
- create_contact
- update_contact
- delete_contact (requires confirmation)
- list_contact_groups
- get_contacts_in_group
- create_contact_group
- add_contact_to_group
- find_incomplete_contacts (find contacts missing key fields)
- list_all_contacts (with limit/offset pagination)
- merge_contacts (merge source into target, requires confirmation)
- bulk_update_contacts (update fields across multiple contacts)

#### 7. Safari (via NSAppleScript)
- list_open_tabs (all windows — title, URL)
- list_reading_list (title, URL, date added, read/unread)
- search_bookmarks (keyword)
- search_history (keyword, date range)
- list_bookmark_folders (list all bookmark folders)
- find_duplicate_tabs (find tabs open to the same URL)
- get_tab_content (get page content from a tab)
- add_to_reading_list (add URL to reading list)
- add_bookmark (add bookmark to a folder)
- delete_bookmark (require confirmation)
- create_bookmark_folder (create new bookmark folder)
- close_tab (by index or URL — require confirmation)
- close_tabs_matching (close tabs matching URL pattern — require confirmation)
- new_tab (open URL in a new tab)
- reload_tab (reload a tab)

#### 8. Finder & Spotlight
- spotlight_search (mdfind query — paths, kinds,
  dates, sizes)
- spotlight_search_content (search inside file contents)
- get_file_metadata (mdls — tags, dates, kind, size,
  where-from URL)
- set_finder_tags (apply/remove color and text tags)
- list_finder_tags (all tags on the system)
- get_tagged_files (all files with a specific tag)

#### 9. Shortcuts (via shortcuts CLI)
- list_shortcuts
- run_shortcut (name, optional input, return output —
  require confirmation for destructive shortcuts)
- get_shortcut_details

#### 10. Cross-App (aggregator — no own bridge)
- meeting_context (get upcoming meetings with attendee
  contact info and recent email threads)
- contact_360 (full 360-degree view of a contact:
  details, emails, messages, calendar events)

### Security Requirements
- ZERO outbound network connections
- No analytics, telemetry, crash reporting
- No disk writes except:
  - ~/.macos-local-mcp/server.log (rotated, max configurable)
  - ~/.macos-local-mcp/server.pid
  - ~/.macos-local-mcp/heartbeat
  - ~/.macos-local-mcp/config.json (read + watch)
  - ~/.macos-local-mcp/activity.jsonl (structured tool call log
    for admin app to read)
- All runtime files created with restrictive permissions
  (directories 0o700, files 0o600)
- All data passes only through stdio
- Default-deny: all modules read-only by default, write
  access requires explicit opt-in per module
- Destructive actions require confirmation: true parameter
- Injection prevention:
  - AppleScript: CR/LF stripping on all string inputs
  - SQL (Safari history): single-quote doubling
  - Spotlight: query sanitization
  - Shell: Process with separate arguments (no interpolation)
- Path traversal protection: file operations block access
  to system directories (/System, /Library, /usr, /bin,
  /sbin, /etc, /var)
- Multiple local clients supported: each MCP client (Claude
  Desktop, Claude Code) spawns its own subprocess via stdio

### Activity Log Format (~/.macos-local-mcp/activity.jsonl)
One JSON object per line, appended by the server, read by the admin app:
```json
{"ts":"2026-03-01T14:23:01Z","tool":"list_reminders","params":{"list":"Work"},"status":"success","duration_ms":45,"result_count":12}
{"ts":"2026-03-01T14:23:15Z","tool":"send_message","params":{"to":"+1234567890"},"status":"confirmation_required","duration_ms":2}
{"ts":"2026-03-01T14:24:02Z","tool":"search_mail","params":{"query":"invoice"},"status":"error","error":"Mail automation permission denied","duration_ms":120}
```

---

## PART 2: ADMIN APP (Native SwiftUI macOS App)

### App Identity

**Name:** macOS Local MCP
**Bundle ID:** com.amargautam.macos-local-mcp-admin

**App Icon:**
Design a proper macOS app icon following Apple's Human Interface
Guidelines for macOS app icons:
- Use the rounded-rectangle (squircle) shape that macOS uses
  for all Dock icons
- Design concept: A bridge/connector visual metaphor — show a
  stylized bridge or link symbol connecting the Apple logo
  silhouette to a terminal/command prompt symbol
- Color palette: Use Apple's system blue as the primary color
  with a subtle gradient (matching the macOS aesthetic), white
  iconography on top
- The icon should feel native alongside System Settings,
  Activity Monitor, and Keychain Access — professional,
  utilitarian, trustworthy
- Must look crisp at all required sizes: 16x16, 32x32, 64x64,
  128x128, 256x256, 512x512, 1024x1024
- Generate the icon as an SF Symbol composition or as
  a programmatic SwiftUI view that renders to an Asset Catalog
  .appiconset with all required sizes
- NO cartoonish AI-generated aesthetics. Think Apple system
  utility, not App Store novelty.

**Dock Behavior:**
- Shows in the Dock like a regular app (LSUIElement = false)
- Standard macOS window with title bar, traffic lights,
  resize handles
- Remembers window position and size between launches
- Supports full screen mode

### Design Language — Native macOS

The app must look and feel like it was built by Apple.
Follow these principles strictly:

**DO use:**
- SwiftUI with native macOS controls exclusively
- NavigationSplitView for sidebar + detail layout
  (like System Settings, Xcode, Mail)
- Standard macOS sidebar with SF Symbols icons
- Native List, Table, Form, GroupBox, Section views
- System fonts (.title, .headline, .body, .caption) —
  San Francisco only
- System colors (.primary, .secondary, .accentColor,
  .red, .green, .orange, .yellow)
- Standard macOS spacing and padding (use .padding() defaults)
- Native Toggle, Picker, Button, TextField styles
- NSToolbar for top toolbar actions
- Standard macOS sheet presentations and alerts
- Vibrancy and translucency where macOS uses it
  (sidebar, toolbar)
- @AppStorage for persisting user preferences
- Standard Cmd+, for Settings window

**DO NOT use:**
- Custom colors, gradients, or themes
- Custom fonts
- Custom button styles (unless matching a system style)
- Cards, rounded rectangles, or web-style layouts
- Shadows or elevation (not the macOS way)
- Any web/iOS design patterns
- Hamburger menus
- Tab bars at the bottom
- Any non-native controls

### App Structure — Sidebar Navigation

```
┌──────────────────────────────────────────────────┐
│ 🔴🟡🟢  macOS Local MCP              ▶ Start     │
├────────────┬─────────────────────────────────────┤
│            │                                     │
│ ⬡ Overview │  [Selected section content]         │
│ 📋 Activity│                                     │
│ 🔑 Access  │                                     │
│ 🧩 Modules │                                     │
│ 🧪 Tester  │                                     │
│ ⚙ Settings │                                     │
│            │                                     │
│            │                                     │
│            │                                     │
├────────────┴─────────────────────────────────────┤
│ ● Server Running · Uptime 4h 23m                 │
└──────────────────────────────────────────────────┘
```

### Sections

#### 1. Overview (default/home section)
Main dashboard showing at-a-glance status:

**Server Status Card:**
- Large status indicator: "Running" (green) / "Stopped" (red)
  / "Starting..." (yellow)
- Uptime since last start
- PID and memory usage
- Start / Stop / Restart buttons in the toolbar

**Quick Stats (using native macOS metrics style):**
- Total tool calls today
- Success rate (%)
- Most used tool
- Last activity timestamp

**Recent Activity (compact list, last 10 entries):**
- Timestamp, tool name, status (green checkmark / red x /
  yellow warning)
- "See all →" link to Activity section

**Connection Status:**
- Claude Desktop: Connected / Not connected
  (detect if stdio pipe is active via PID inspection)
- Last request from Claude: timestamp

#### 2. Activity (live feed)
Full activity log from ~/.macos-local-mcp/activity.jsonl:

**Toolbar:** Filter chips for module (Reminders, Calendar, etc.),
status (Success, Error, Confirmation Required), search field

**Table view (native macOS Table):**
| Time | Tool | Parameters | Status | Duration |
|------|------|-----------|--------|----------|
| 2:23 PM | list_reminders | list: "Work" | ✅ | 45ms |
| 2:24 PM | send_message | to: +1234... | ⚠️ Needs confirm | 2ms |
| 2:25 PM | search_mail | query: "invoice" | ❌ Permission | 120ms |

- Click any row to expand full request/response JSON in a
  detail panel below the table (like Console.app)
- Color coding: green rows for success, red for error,
  yellow for confirmation_required
- Live updating via FSEvents watching activity.jsonl
- Pause/Resume button
- "Clear" button (archives current log, starts fresh)
- Export button (save as .json or .csv)

#### 3. Access (permission status)
Shows macOS permission status for each Apple framework:

**List view with status indicators:**
```
Calendar         ✅ Authorized         [Open Settings]
Reminders        ✅ Authorized         [Open Settings]
Contacts         ✅ Authorized         [Open Settings]
Mail             ⚠️ Automation needed  [Grant Access]
Messages         ⚠️ Automation needed  [Grant Access]
Notes            ⚠️ Automation needed  [Grant Access]
Safari           ❌ Not authorized     [Grant Access]
Accessibility    ✅ Authorized         [Open Settings]
Full Disk Access ⚠️ Recommended       [Open Settings]
```

- Each row shows the framework, current authorization status,
  and an action button
- "Grant Access" triggers the macOS permission prompt
  or opens System Settings to the correct pane
- "Refresh" button to re-check all permissions
- Info text explaining why each permission is needed
- "Fix All" button that walks through granting all
  missing permissions one by one

#### 4. Modules (toggle panel)
Grid or list of all 10 modules with toggles:

**Each module card shows:**
- Module name + SF Symbol icon
- Toggle (on/off) — writes to config.json
- Tool count (e.g., "6 tools")
- Last used timestamp
- Calls today count
- Status: Active / Disabled / Permission Missing

**Module detail (click to expand or navigate):**
- List of all tools in the module with descriptions
- Per-tool enable/disable (stretch goal)
- Per-tool confirmation requirement toggle

**Confirmation Settings (sub-section):**
- List of all actions that can require confirmation
- Toggle each one on/off
- Default: all destructive actions require confirmation

#### 5. Tester (tool testing interface)
Interactive tool tester — like a Postman for your MCP server:

**Left panel:** Dropdown/list of all available tools,
grouped by module

**Right panel (on tool selection):**
- Tool description
- Auto-generated form with input fields based on the
  tool's parameter schema
- Required fields marked, optional fields collapsible
- "confirmation" checkbox auto-checked for destructive tools
- "Run" button
- Response area showing formatted JSON result
- Duration and status
- "Copy Response" button

**Test presets:** Save and recall frequently used test
configurations (e.g., "list today's events",
"search reminders for 'grocery'")

#### 6. Settings
Standard macOS settings view (Form/GroupBox style):

**General:**
- Launch at login toggle (registers/unregisters LaunchAgent)
- Server binary path (with file picker)
- Config directory path

**Logging:**
- Log level picker: Verbose / Normal / Quiet
- Log rotation size (MB) — slider or stepper
- Activity log retention (days)
- "Open Log in Console" button
- "Open Activity Log" button

**Claude Desktop:**
- Show the JSON config snippet needed for
  claude_desktop_config.json
- "Copy to Clipboard" button
- "Auto-configure" button that writes to the config
  file directly (with confirmation)
- Detected Claude Desktop installation status

**Advanced:**
- Heartbeat interval (seconds)
- Server timeout settings
- "Reset to Defaults" button
- "Uninstall Everything" button (with confirmation dialog
  that explains what will be removed: binary, LaunchAgent,
  config directory, logs)

**About:**
- Version number
- Build date
- Link to SECURITY.md
- Link to README.md

### First-Run Experience
On first launch, if the server binary is not found or
LaunchAgent is not installed:

1. Welcome screen explaining what macOS Local MCP does
2. "Set Up" button that:
   a. Builds the binary (or locates pre-built binary)
   b. Creates ~/.macos-local-mcp/ directory
   c. Installs LaunchAgent
   d. Starts the server
   e. Walks through each macOS permission request
      with explanation
   f. Shows Claude Desktop config snippet to copy
3. "All Set!" confirmation with overview dashboard

### Status Bar Item (in addition to Dock)
Even though it's a full window app, also add a small
status bar item (NSStatusItem) that shows:
- Green/red dot for server status
- Click to show quick menu:
  - "Server: Running" / "Server: Stopped"
  - Start / Stop / Restart
  - "Open macOS Local MCP" (brings window to front)
  - Quit

This way the user can check server status at a glance
even when the main window is closed.

---

## PART 3: TESTING ARCHITECTURE

### Test Layers

**Layer 1 — Protocol Tests (Phase 0)**
- JSON-RPC parsing (valid, malformed, edge cases)
- Tool routing (known tool, unknown tool, disabled tool)
- Response formatting
- Initialize/list_tools/call_tool lifecycle
- Error codes and messages

**Layer 2 — Bridge Tests (per framework)**
- EventKitBridge with mock EKEventStore
- AppleScriptBridge: verify script generation without execution
- ContactsBridge with mock CNContactStore
- ShellBridge with mock Process
- SpotlightBridge with mock mdfind output

**Layer 3 — Tool Tests (per tool)**
For every single tool, test:
- Valid input → correct response structure
- Missing required parameters → descriptive error
- Invalid parameter types → descriptive error
- Empty results → graceful empty response (not error)
- Permission denied → clear error with fix instructions
- Confirmation-required without confirmation: true → error

**Layer 4 — Integration Tests (shell scripts)**
Per-module test scripts that:
- Create test data in a "[TEST] macOS Local MCP" list/calendar/folder
- Read back and verify
- Update and verify
- Clean up after themselves
- NEVER touch real user data

**Layer 5 — Admin App Tests**
- Config file read/write round-trips
- Permission status detection logic
- Server status detection (PID/heartbeat)
- Activity log parsing
- Module toggle → config update flow

### Test Conventions
- Every source file has a corresponding test file
- Protocol-based DI: every bridge has a protocol,
  real bridge and mock both conform
- Minimum 3 tests per tool function:
  happy path, error case, edge case
- Name tests descriptively:
  test_listReminders_withDueDateFilter_returnsFilteredResults()
  test_listReminders_withNoReminders_returnsEmptyArray()
  test_listReminders_withPermissionDenied_returnsErrorWithFixInstructions()

---

## PART 4: PROJECT STRUCTURE

```
macos-local-mcp-swift/
├── Package.swift
├── README.md
├── SECURITY.md
├── PrivacyInfo.xcprivacy
├── install.sh
├── uninstall.sh
├── com.amargautam.macos-local-mcp.plist
│
├── Sources/
│   ├── MacOSLocalMCP/                          # Server binary
│   │   ├── main.swift
│   │   ├── MCPServer.swift
│   │   ├── ConfigManager.swift            # Reads/watches config.json
│   │   ├── ActivityLogger.swift           # Writes activity.jsonl
│   │   ├── HeartbeatManager.swift         # Writes heartbeat file
│   │   ├── Protocols/
│   │   │   ├── RemindersProviding.swift
│   │   │   ├── CalendarProviding.swift
│   │   │   ├── MailProviding.swift
│   │   │   ├── MessagesProviding.swift
│   │   │   ├── NotesProviding.swift
│   │   │   ├── ContactsProviding.swift
│   │   │   ├── SafariProviding.swift
│   │   │   ├── FinderProviding.swift
│   │   │   └── ShortcutsProviding.swift
│   │   ├── Tools/
│   │   │   ├── RemindersTool.swift
│   │   │   ├── CalendarTool.swift
│   │   │   ├── MailTool.swift
│   │   │   ├── MessagesTool.swift
│   │   │   ├── NotesTool.swift
│   │   │   ├── ContactsTool.swift
│   │   │   ├── SafariTool.swift
│   │   │   ├── FinderTool.swift
│   │   │   ├── ShortcutsTool.swift
│   │   │   └── CrossAppTool.swift
│   │   ├── Bridges/
│   │   │   ├── EventKitBridge.swift
│   │   │   ├── AppleScriptBridge.swift
│   │   │   ├── ContactsBridge.swift
│   │   │   ├── ShellBridge.swift
│   │   │   └── SpotlightBridge.swift
│   │   └── Models/
│   │       ├── MCPTypes.swift
│   │       └── ToolDefinitions.swift
│   │
│   └── MacOSLocalMCPAdmin/                     # SwiftUI macOS app
│       ├── MacOSLocalMCPAdminApp.swift          # @main, WindowGroup, MenuBarExtra
│       ├── Assets.xcassets/               # App icon
│       │   └── AppIcon.appiconset/
│       │       ├── Contents.json
│       │       ├── icon_16x16.png
│       │       ├── icon_16x16@2x.png
│       │       ├── icon_32x32.png
│       │       ├── icon_32x32@2x.png
│       │       ├── icon_128x128.png
│       │       ├── icon_128x128@2x.png
│       │       ├── icon_256x256.png
│       │       ├── icon_256x256@2x.png
│       │       ├── icon_512x512.png
│       │       └── icon_512x512@2x.png
│       ├── Info.plist
│       ├── Models/
│       │   ├── ServerStatus.swift          # Server status monitoring
│       │   ├── ActivityEntry.swift         # Parsed activity.jsonl entry
│       │   ├── PermissionStatus.swift      # Per-framework permission state
│       │   ├── ModuleConfig.swift          # Module enable/disable state
│       │   └── AppConfig.swift             # App-level settings
│       ├── Services/
│       │   ├── ServerMonitor.swift         # PID + heartbeat watching
│       │   ├── ActivityFeedService.swift   # FSEvents on activity.jsonl
│       │   ├── ConfigService.swift         # Read/write config.json
│       │   ├── PermissionChecker.swift     # Check all macOS permissions
│       │   ├── LaunchAgentManager.swift    # launchctl load/unload
│       │   └── ToolTesterService.swift     # Send JSON-RPC to server
│       ├── Views/
│       │   ├── Sidebar/
│       │   │   └── SidebarView.swift
│       │   ├── Overview/
│       │   │   ├── OverviewView.swift
│       │   │   ├── ServerStatusCard.swift
│       │   │   ├── QuickStatsView.swift
│       │   │   └── RecentActivityView.swift
│       │   ├── Activity/
│       │   │   ├── ActivityView.swift
│       │   │   ├── ActivityTableView.swift
│       │   │   ├── ActivityDetailView.swift
│       │   │   └── ActivityFilterBar.swift
│       │   ├── Access/
│       │   │   ├── AccessView.swift
│       │   │   └── PermissionRow.swift
│       │   ├── Modules/
│       │   │   ├── ModulesView.swift
│       │   │   ├── ModuleCard.swift
│       │   │   └── ModuleDetailView.swift
│       │   ├── Tester/
│       │   │   ├── TesterView.swift
│       │   │   ├── ToolPickerView.swift
│       │   │   ├── ToolFormView.swift
│       │   │   └── ToolResponseView.swift
│       │   ├── Settings/
│       │   │   ├── SettingsView.swift
│       │   │   ├── GeneralSettingsView.swift
│       │   │   ├── LoggingSettingsView.swift
│       │   │   ├── ClaudeDesktopSettingsView.swift
│       │   │   ├── AdvancedSettingsView.swift
│       │   │   └── AboutView.swift
│       │   ├── Setup/
│       │   │   ├── SetupWizardView.swift
│       │   │   └── SetupStepView.swift
│       │   └── StatusBar/
│       │       └── StatusBarMenu.swift
│       └── IconGenerator/
│           └── AppIconGenerator.swift      # Programmatic icon generation
│
├── Tests/
│   └── MacOSLocalMCPTests/
│       ├── Mocks/
│       │   ├── MockRemindersProvider.swift
│       │   ├── MockCalendarProvider.swift
│       │   ├── MockMailProvider.swift
│       │   ├── MockMessagesProvider.swift
│       │   ├── MockNotesProvider.swift
│       │   ├── MockContactsProvider.swift
│       │   ├── MockSafariProvider.swift
│       │   ├── MockFinderProvider.swift
│       │   └── MockShortcutsProvider.swift
│       ├── Protocol/
│       │   ├── MCPServerTests.swift
│       │   ├── JSONRPCParsingTests.swift
│       │   └── ToolRoutingTests.swift
│       ├── Bridge/
│       │   ├── EventKitBridgeTests.swift
│       │   ├── AppleScriptBridgeTests.swift
│       │   ├── ContactsBridgeTests.swift
│       │   ├── ShellBridgeTests.swift
│       │   └── SpotlightBridgeTests.swift
│       ├── Tool/
│       │   ├── RemindersToolTests.swift
│       │   ├── CalendarToolTests.swift
│       │   ├── MailToolTests.swift
│       │   ├── MessagesToolTests.swift
│       │   ├── NotesToolTests.swift
│       │   ├── ContactsToolTests.swift
│       │   ├── SafariToolTests.swift
│       │   ├── FinderToolTests.swift
│       │   ├── ShortcutsToolTests.swift
│       │   └── CrossAppToolTests.swift
│       ├── Config/
│       │   ├── ConfigManagerTests.swift
│       │   └── ActivityLoggerTests.swift
│       └── Admin/
│           ├── ServerMonitorTests.swift
│           ├── ActivityFeedServiceTests.swift
│           ├── ConfigServiceTests.swift
│           └── PermissionCheckerTests.swift
│
└── IntegrationTests/
    ├── test_all.sh
    ├── test_reminders.sh
    ├── test_calendar.sh
    ├── test_mail.sh
    ├── test_messages.sh
    ├── test_notes.sh
    ├── test_contacts.sh
    ├── test_safari.sh
    ├── test_finder.sh
    └── test_shortcuts.sh
```

---

## PART 5: BUILD ORDER (TDD + Agent Teams + Code Review)

Every phase follows this cycle:
1. Architect assigns phase to specialist agent
2. Specialist writes tests FIRST (TDD red)
3. Specialist implements to pass tests (TDD green)
4. Specialist refactors (TDD refactor)
5. Specialist runs swift test — all green
6. Specialist runs integration test script
7. Architect spawns code-reviewer to review
8. Code-reviewer runs full review checklist
9. If issues → specialist fixes → re-review
10. If clean → architect marks phase APPROVED in PROGRESS.md

### Phase 0: Foundation
**Agent:** protocol-engineer
**Parallel:** None — must complete first
1. Write MCPServerTests + JSONRPCParsingTests + ToolRoutingTests
2. Implement MCPServer.swift, MCPTypes.swift to make them pass
3. Write ConfigManagerTests
4. Implement ConfigManager.swift
5. Write ActivityLoggerTests
6. Implement ActivityLogger.swift
7. Write HeartbeatManager (simple, minimal test)
8. Write ALL Protocols (interfaces only)
9. Write ALL Mocks
10. `swift test` — all green
11. **CODE REVIEW by code-reviewer**
12. **APPROVED → advance**

### Phase 1: Reminders + Calendar
**Agent:** eventkit-engineer | **Parallel with:** Phase 3
1. Write RemindersToolTests — tests FIRST
2. Implement RemindersTool + EventKitBridge → tests pass
3. Write CalendarToolTests — tests FIRST
4. Implement CalendarTool + extend EventKitBridge → tests pass
5. Run test_reminders.sh and test_calendar.sh
6. `swift test` — all green
7. **CODE REVIEW** → **APPROVED → advance**

### Phase 2: Contacts
**Agent:** eventkit-engineer | **Parallel with:** Phases 4-7
1. Write ContactsToolTests → Implement → tests pass
2. Run test_contacts.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 3: Finder + Spotlight
**Agent:** system-engineer | **Parallel with:** Phase 1
1. Write FinderToolTests → Implement + SpotlightBridge + ShellBridge → tests pass
2. Run test_finder.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 4: Mail
**Agent:** applescript-engineer | **Parallel with:** Phases 2, 8
1. Write MailToolTests → Implement + AppleScriptBridge → tests pass
2. Run test_mail.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 5: Notes
**Agent:** applescript-engineer | **After:** Phase 4
1. Write NotesToolTests → Implement → tests pass
2. Run test_notes.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 6: Messages
**Agent:** applescript-engineer | **After:** Phase 4
1. Write MessagesToolTests → Implement → tests pass
2. Run test_messages.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 7: Safari
**Agent:** applescript-engineer | **After:** Phase 4
1. Write SafariToolTests → Implement → tests pass
2. Run test_safari.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 8: Shortcuts
**Agent:** system-engineer | **Parallel with:** Phases 4-7
1. Write ShortcutsToolTests → Implement → tests pass
2. Run test_shortcuts.sh | `swift test` — all green
3. **CODE REVIEW** → **APPROVED → advance**

### Phase 9: ~~System~~ (Removed)
System module was removed during post-completion hardening.
Tools (`run_shell`, `get_clipboard`, `set_clipboard`) were deemed
security risks and deleted.

### Phase 10: Admin App
**Agent:** ui-engineer | **Starts after:** Phase 0
1. Write service tests FIRST
2. Implement services → tests pass
3. Build SwiftUI views section by section
4. Generate app icon
5. Full build verification
6. **CODE REVIEW** (extra scrutiny on native macOS design) → **APPROVED**

### Phase 11: Install & Integration
**Agent:** architect + code-reviewer | **Requires:** ALL phases approved
1. Build release binary
2. Test install.sh and uninstall.sh
3. End-to-end smoke test (all modules + admin app)
4. Resilience tests (crash recovery, sleep/wake, login/logout)
5. **FINAL CODE REVIEW** — full codebase security + coverage audit
6. **FINAL APPROVED → project complete**

### Parallel Execution Map
```
Phase 0  ████████░r░  (protocol-engineer)
Phase 1  ·········████████░r░  (eventkit)
Phase 3  ·········████░r░      (system)        ← parallel
Phase 2  ··················████░r░  (eventkit)
Phase 4  ··················████████░r░  (applescript) ← parallel
Phase 8  ······················████░r░  (system)      ← parallel
Phase 5  ······························████░r░  (applescript)
Phase 6  ··································████░r░
Phase 7  ······································████░r░
Phase 10 ·········████████████████████████████░r░  (ui)
Phase 11 ·············································████░FINAL░
```

---

## PART 6: INSTALL & UNINSTALL SCRIPTS

### install.sh
```bash
#!/bin/bash
set -e

echo "Building macOS Local MCP Server..."
swift build -c release

echo "Installing binary..."
mkdir -p ~/bin
cp .build/release/macos-local-mcp ~/bin/macos-local-mcp
chmod +x ~/bin/macos-local-mcp

echo "Creating config directory..."
mkdir -p ~/.macos-local-mcp

# Write default config if none exists (read-only defaults)
if [ ! -f ~/.macos-local-mcp/config.json ]; then
    cat > ~/.macos-local-mcp/config.json << 'EOF'
{
  "logLevel": "normal",
  "logMaxSizeMB": 10,
  "enabledModules": {
    "reminders": {"read": true, "write": false},
    "calendar": {"read": true, "write": false},
    "mail": {"read": true, "write": false},
    "messages": {"read": true, "write": false},
    "notes": {"read": true, "write": false},
    "contacts": {"read": true, "write": false},
    "safari": {"read": true, "write": false},
    "finder": {"read": true, "write": false},
    "shortcuts": {"read": true, "write": false},
    "crossapp": {"read": true, "write": false}
  }
}
EOF
fi

echo "Installing Admin App..."
# Build and copy to Applications
# (Xcode build or swift build depending on setup)

echo "Server started. Triggering permission requests..."
# Run a quick test to trigger macOS permission dialogs
~/bin/macos-local-mcp --test-permissions

echo ""
echo "✅ Installation complete!"
echo ""
echo "Add this to Claude Desktop config:"
echo "~/Library/Application Support/Claude/claude_desktop_config.json"
echo ""
cat << 'EOF'
{
  "mcpServers": {
    "macos-local-mcp": {
      "command": "$HOME/bin/macos-local-mcp",
      "transport": "stdio"
    }
  }
}
EOF
echo ""
echo "Then restart Claude Desktop."
```

### uninstall.sh
```bash
#!/bin/bash
set -e

echo "Stopping server..."
launchctl unload ~/Library/LaunchAgents/com.amargautam.macos-local-mcp.plist 2>/dev/null || true

echo "Removing LaunchAgent..."
rm -f ~/Library/LaunchAgents/com.amargautam.macos-local-mcp.plist

echo "Removing binary..."
rm -f ~/bin/macos-local-mcp

echo "Removing Admin App..."
rm -rf "/Applications/macOS Local MCP.app"

echo ""
read -p "Remove config and logs (~/.macos-local-mcp/)? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.macos-local-mcp
    echo "Config and logs removed."
else
    echo "Config and logs preserved at ~/.macos-local-mcp/"
fi

echo ""
echo "✅ Uninstall complete."
echo "Remember to remove the macos-local-mcp entry from"
echo "Claude Desktop's claude_desktop_config.json"
```

---

## PART 7: CLIENT CONFIGURATION

### Claude Desktop
Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "macOS Local MCP Server": {
      "command": "$HOME/bin/macos-local-mcp"
    }
  }
}
```

Restart Claude Desktop. All modules and 83 tools
will appear as available tools.

### Claude Code
Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "macOS Local MCP Server": {
      "command": "$HOME/bin/macos-local-mcp"
    }
  }
}
```

Multiple clients can use the server simultaneously —
each spawns its own isolated subprocess via stdio.

---

## CRITICAL REMINDERS

1. TDD: Tests FIRST, always. No exceptions.
2. `swift test` must pass before requesting code review.
3. CODE REVIEW: No phase is complete until code-reviewer
   approves. No exceptions.
4. Zero network: grep the entire codebase for URLSession,
   URL(string:), NSURLConnection — none should exist.
5. Every destructive action requires confirmation: true.
6. Integration tests use "[TEST] macOS Local MCP" prefixed
   test data and clean up after themselves.
7. The admin app communicates with the server ONLY
   through the filesystem (config.json, activity.jsonl,
   server.pid, heartbeat). No IPC, no sockets.
8. Native macOS design only. If it doesn't look like
   it belongs next to System Settings, redo it.
9. AGENTS: Each agent works only on their assigned modules.
   No cross-module edits without architect approval.
10. REVIEW GATE: The cycle is always:
    implement → tests green → code review → approved → advance.
    Never skip the review step.
11. PROGRESS: Architect updates PROGRESS.md after every
    phase approval and after every review cycle.
12. No force unwraps (!) in production code.
13. Every public function must have at least 3 tests.
