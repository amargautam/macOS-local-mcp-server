<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/MCP-2024--11--05-6366F1?style=flat-square" alt="MCP Protocol" />
  <img src="https://img.shields.io/badge/Tools-83-10B981?style=flat-square" alt="83 Tools" />
  <img src="https://img.shields.io/badge/Tests-811-3B82F6?style=flat-square" alt="811 Tests" />
  <img src="https://img.shields.io/badge/Dependencies-Zero-EAB308?style=flat-square" alt="Zero Dependencies" />
</p>

<h1 align="center">macOS Local MCP Server</h1>

<p align="center">
  <strong>Bridge Claude Desktop to every native app on your Mac.</strong>
  <br />
  <em>Reminders &middot; Calendar &middot; Mail &middot; Messages &middot; Notes &middot; Contacts &middot; Safari &middot; Finder &middot; Shortcuts &middot; Cross-App</em>
</p>

<br />

A local [Model Context Protocol](https://modelcontextprotocol.io/) server written in Swift that gives Claude direct access to **10 macOS modules** through **83 tool handlers** — plus a native SwiftUI admin app for managing everything.

**Zero network. Zero dependencies. Zero telemetry.** Everything runs locally on your Mac.

---

## What It Does

macOS Local MCP Server turns Claude into a native macOS power tool. Works with Claude Desktop, Claude Code, or any MCP client. Ask Claude to:

- *"What's on my calendar this week?"* — reads Calendar via EventKit
- *"Remind me to call the dentist tomorrow at 9am"* — creates a Reminder
- *"Search my email for the invoice from Acme Corp"* — searches Mail
- *"Send a message to Sarah: I'm running 10 minutes late"* — sends an iMessage (with confirmation)
- *"Find all PDFs on my Desktop"* — searches Spotlight
- *"Run my 'Morning Routine' shortcut"* — executes Shortcuts (with confirmation)
- *"Prep me for my 2pm meeting"* — aggregates calendar, contacts, and email context

All 83 tools work through the MCP protocol over stdio — no HTTP server, no cloud relay, no API keys.

---

## Architecture

```
┌──────────────────┐                                      ┌──────────────────────┐
│  Claude Desktop  │──┐                                   │                      │
└──────────────────┘  │    stdio (JSON-RPC 2.0)           │  macos-local-mcp server │
┌──────────────────┐  ├──────────────────────────────────► │                      │
│   Claude Code    │──┘   (each client spawns its own)    │                      │
└──────────────────┘                                      └──────────┬───────────┘
                                                                     │
                              ┌──────────────────────────────────────┼──────────────────────────────┐
                              │                                      │                              │
                    ┌─────────▼──────────┐             ┌─────────────▼───────────┐      ┌───────────▼──────────┐
                    │    EventKit         │             │    NSAppleScript / JXA   │      │    Shell Commands     │
                    │  Reminders          │             │  Mail                    │      │  Finder / Spotlight   │
                    │  Calendar           │             │  Messages                │      │  Shortcuts            │
                    │  Contacts           │             │  Notes                   │      └──────────────────────┘
                    └────────────────────┘             │  Safari                  │
                                                       └─────────────────────────┘
                    ┌────────────────────────────┐
                    │  Cross-App (aggregator)     │  ← Combines data from multiple
                    │  meeting_context             │     providers (no own bridge)
                    │  contact_360                 │
                    └────────────────────────────┘

┌──────────────────────────┐
│  macOS Local MCP Admin   │  ← SwiftUI app in /Applications
│  (reads ~/.macos-local-mcp/) │  Monitors server, manages config,
│                          │     controls read/write access per module
└──────────────────────────┘
```

**Two build targets:**

| Binary | Description |
|--------|-------------|
| `macos-local-mcp` | Headless MCP server. Communicates via stdin/stdout. Each MCP client spawns its own process. |
| `macOS Local MCP Server.app` | Native SwiftUI admin app. Monitors server status, activity log, permissions, and module config. |

---

## Tools

### 83 tools across 10 modules

Each tool is classified as **read** or **write**, giving you granular control over what Claude can access.

<details>
<summary><strong>Reminders</strong> — 8 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_reminder_lists` | Read | List all reminder lists (categories) |
| `list_reminders` | Read | List reminders with filters (list, date range, status, priority) |
| `search_reminders` | Read | Search reminders by text query |
| `create_reminder` | Write | Create a reminder with due date, priority, list assignment |
| `update_reminder` | Write | Update a reminder's properties |
| `complete_reminder` | Write | Mark a reminder as completed |
| `move_reminder` | Write | Move a reminder to a different list |
| `bulk_move_reminders` | Write | Move multiple reminders between lists at once |

</details>

<details>
<summary><strong>Calendar</strong> — 11 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_calendars` | Read | List all available calendars |
| `list_events` | Read | List events within a date range |
| `search_events` | Read | Search events by text query |
| `check_availability` | Read | Check availability for a time range |
| `find_conflicts` | Read | Find overlapping/conflicting events in a date range |
| `find_gaps` | Read | Find free time slots between events |
| `get_calendar_stats` | Read | Get event count and time statistics for a date range |
| `create_event` | Write | Create a calendar event |
| `update_event` | Write | Update an existing event |
| `delete_event` | Write | Delete an event *(requires confirmation)* |
| `bulk_decline_events` | Write | Decline multiple events at once *(requires confirmation)* |

</details>

<details>
<summary><strong>Contacts</strong> — 13 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `search_contacts` | Read | Search by name, email, phone, or company |
| `get_contact` | Read | Get full details including createdAt/modifiedAt dates |
| `list_contact_groups` | Read | List all contact groups |
| `get_contacts_in_group` | Read | Get all contacts in a group |
| `find_incomplete_contacts` | Read | Find contacts missing key fields (email, phone, company) |
| `list_all_contacts` | Read | List all contacts with limit/offset pagination |
| `create_contact` | Write | Create a new contact |
| `update_contact` | Write | Update a contact's information |
| `delete_contact` | Write | Delete a contact *(requires confirmation)* |
| `bulk_update_contacts` | Write | Update fields across multiple contacts at once |
| `merge_contacts` | Write | Merge two contacts into one *(requires confirmation)* |
| `create_contact_group` | Write | Create a new contact group |
| `add_contact_to_group` | Write | Add a contact to a group |

</details>

<details>
<summary><strong>Mail</strong> — 12 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_mailboxes` | Read | List all mail accounts and mailboxes |
| `list_recent_mail` | Read | List recent emails with filters |
| `search_mail` | Read | Search by sender, subject, body, date, attachments |
| `read_mail` | Read | Read full content of a message |
| `find_unanswered_mail` | Read | Find received emails you haven't replied to |
| `find_threads_awaiting_reply` | Read | Find threads where you're waiting for a response |
| `list_senders_by_frequency` | Read | List senders ranked by email frequency |
| `create_draft` | Write | Create a new email draft |
| `send_draft` | Write | Send a draft *(requires confirmation)* |
| `move_message` | Write | Move a message to another mailbox |
| `flag_message` | Write | Flag or mark read/unread |
| `bulk_archive_messages` | Write | Archive multiple messages at once *(requires confirmation)* |

</details>

<details>
<summary><strong>Messages</strong> — 4 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_conversations` | Read | List recent iMessage/SMS conversations |
| `read_conversation` | Read | Read messages from a conversation |
| `search_messages` | Read | Search message history |
| `send_message` | Write | Send an iMessage or SMS *(requires confirmation)* |

</details>

<details>
<summary><strong>Notes</strong> — 9 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_note_folders` | Read | List all note folders/accounts |
| `list_notes` | Read | List notes with filters, sorting, and limit/offset pagination |
| `read_note` | Read | Read full content of a note |
| `search_notes` | Read | Search notes by text query |
| `find_stale_notes` | Read | Find notes not modified within N days, with pagination |
| `create_note` | Write | Create a new note |
| `update_note` | Write | Update a note's content |
| `delete_note` | Write | Delete a note *(requires confirmation)* |
| `append_to_note` | Write | Append text to an existing note |

</details>

<details>
<summary><strong>Safari</strong> — 15 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_open_tabs` | Read | List all open tabs across windows |
| `list_reading_list` | Read | List Reading List items |
| `search_bookmarks` | Read | Search bookmarks |
| `search_history` | Read | Search browsing history |
| `list_bookmark_folders` | Read | List all bookmark folders |
| `find_duplicate_tabs` | Read | Find tabs open to the same URL |
| `get_tab_content` | Read | Get page content from a tab |
| `add_to_reading_list` | Write | Add a URL to the Reading List |
| `add_bookmark` | Write | Add a bookmark to a folder |
| `delete_bookmark` | Write | Delete a bookmark *(requires confirmation)* |
| `create_bookmark_folder` | Write | Create a new bookmark folder |
| `close_tab` | Write | Close a tab *(requires confirmation)* |
| `close_tabs_matching` | Write | Close all tabs matching a URL pattern *(requires confirmation)* |
| `new_tab` | Write | Open a URL in a new tab |
| `reload_tab` | Write | Reload a tab |

</details>

<details>
<summary><strong>Finder</strong> — 6 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `spotlight_search` | Read | Search files using Spotlight metadata |
| `spotlight_search_content` | Read | Search file contents via Spotlight |
| `get_file_metadata` | Read | Get file size, dates, type, tags |
| `list_finder_tags` | Read | List all Finder tags in use |
| `get_tagged_files` | Read | Get files with a specific tag |
| `set_finder_tags` | Write | Set Finder tags on a file or folder |

</details>

<details>
<summary><strong>Shortcuts</strong> — 3 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `list_shortcuts` | Read | List all available Shortcuts |
| `get_shortcut_details` | Read | Get details about a Shortcut |
| `run_shortcut` | Write | Run a Shortcut by name *(requires confirmation)* |

</details>

<details>
<summary><strong>Cross-App</strong> — 2 tools</summary>

| Tool | Access | Description |
|------|--------|-------------|
| `meeting_context` | Read | Get upcoming meetings with attendee contact info and recent emails |
| `contact_360` | Read | Full 360-degree view of a contact: details, emails, messages, events |

</details>

### Summary

| | Read | Write | Total |
|---|:---:|:---:|:---:|
| **Reminders** | 3 | 5 | 8 |
| **Calendar** | 7 | 4 | 11 |
| **Contacts** | 6 | 7 | 13 |
| **Mail** | 7 | 5 | 12 |
| **Messages** | 3 | 1 | 4 |
| **Notes** | 5 | 4 | 9 |
| **Safari** | 7 | 8 | 15 |
| **Finder** | 5 | 1 | 6 |
| **Shortcuts** | 2 | 1 | 3 |
| **Cross-App** | 2 | 0 | 2 |
| **Total** | **47** | **36** | **83** |

---

## Installation

### Requirements

- **macOS 13.0** (Ventura) or later
- **Swift 5.9+** (included with Xcode 15+)
- **Claude Desktop** ([download](https://claude.ai/download)) or **Claude Code** or any MCP-compatible client

### Quick Install

```bash
git clone https://github.com/amargautam/macos-local-mcp.git
cd macos-local-mcp
bash install.sh
```

This will:
1. Build both targets in release mode
2. Install the server binary to `~/bin/macos-local-mcp`
3. Create the config at `~/.macos-local-mcp/config.json`
4. Install the admin app to `/Applications/macOS Local MCP Server.app`

### Connect to Claude Desktop

Add this to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "macOS Local MCP Server": {
      "command": "/Users/YOUR_USERNAME/bin/macos-local-mcp"
    }
  }
}
```

Replace `YOUR_USERNAME` with your macOS username (run `whoami` to check).

Then **restart Claude Desktop**. The server will appear in the MCP tools section.

### Connect to Claude Code

Add this to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "macOS Local MCP Server": {
      "command": "/Users/YOUR_USERNAME/bin/macos-local-mcp"
    }
  }
}
```

Multiple clients can use the server simultaneously — each spawns its own process.

### macOS Permissions

The first time Claude uses a tool, macOS will prompt you to grant permissions. You'll typically need to allow:

- **Reminders** — Reminders access
- **Calendar** — Calendar access
- **Contacts** — Contacts access
- **Mail / Messages / Notes / Safari** — Automation (AppleScript) access
- **Finder** — Spotlight access (usually pre-authorized)

Grant these in **System Settings > Privacy & Security**. The admin app's **Access** tab shows which permissions are authorized.

---

## Configuration

The config file lives at `~/.macos-local-mcp/config.json`:

```json
{
    "logLevel": "normal",
    "logMaxSizeMB": 10,
    "enabledModules": {
        "reminders": {"read": true, "write": false},
        "calendar":  {"read": true, "write": false},
        "contacts":  {"read": true, "write": false},
        "mail":      {"read": true, "write": false},
        "messages":  {"read": true, "write": false},
        "notes":     {"read": true, "write": false},
        "safari":    {"read": true, "write": false},
        "finder":    {"read": true, "write": false},
        "shortcuts": {"read": true, "write": false},
        "crossapp":  {"read": true, "write": false}
    }
}
```

> **Default: read-only.** All modules ship with write access disabled. Enable write per module as needed.

### Read vs Write Access

Each module can be independently configured for **read** and **write** access:

- **Read** tools: `list_*`, `search_*`, `get_*`, `read_*`, `check_*` — safe, non-destructive queries
- **Write** tools: `create_*`, `update_*`, `delete_*`, `send_*`, `run_*` — actions that modify state

Set a module to `{"read": true, "write": false}` for **read-only** mode. This lets Claude search and view your data without being able to modify anything.

### Confirmation-Required Tools

Thirteen high-impact tools require an explicit `confirmation: true` parameter before executing:

| Tool | Why |
|------|-----|
| `send_message` | Sends an iMessage/SMS to a real person |
| `send_draft` | Sends an email |
| `delete_event` | Permanently removes a calendar event |
| `delete_note` | Permanently removes a note |
| `delete_contact` | Permanently deletes a contact |
| `merge_contacts` | Merges two contacts (deletes source) |
| `close_tab` | Closes a Safari tab |
| `run_shortcut` | Executes arbitrary Shortcuts automation |
| `complete_reminder` | Marks a reminder as completed |
| `bulk_decline_events` | Declines multiple calendar events at once |
| `bulk_archive_messages` | Archives multiple emails at once |
| `delete_bookmark` | Deletes a Safari bookmark |
| `close_tabs_matching` | Closes all tabs matching a URL pattern |

---

## Admin App

Open **macOS Local MCP Server** from `/Applications` or Spotlight.

The admin app provides five views:

| View | Purpose |
|------|---------|
| **Overview** | Server status (running/stopped), PID, uptime, recent activity, quick stats |
| **Activity** | Full tool call log — filter by success/error/confirmation, searchable, sortable |
| **Access** | macOS permission status per module — see what's authorized/denied at a glance |
| **Modules** | Toggle read/write access per module — changes are saved instantly to config |
| **Settings** | Log level, max log size, confirmation requirements per tool |

The admin app reads directly from `~/.macos-local-mcp/` (config, activity log, PID file, heartbeat). It does not communicate with the server process.

---

## Development

### Build

```bash
swift build              # Debug build
swift build -c release   # Release build
```

### Test

```bash
swift test               # Run all 811 tests
```

### Run Locally

```bash
.build/debug/macos-local-mcp   # Start the server (reads from stdin, writes to stdout)
```

### Project Structure

```
Sources/
├── MacOSLocalMCP/                    # MCP server
│   ├── main.swift               # Entry point — wires all 10 modules + cross-app
│   ├── MCPServer.swift          # JSON-RPC server, request routing
│   ├── ConfigManager.swift      # Config parsing, file watching
│   ├── ActivityLogger.swift     # Structured tool call logging
│   ├── HeartbeatManager.swift   # Heartbeat file for admin app
│   ├── Models/
│   │   ├── MCPTypes.swift       # MCP protocol types (JSON-RPC, tools)
│   │   └── ToolDefinitions.swift # All 83 tool schemas + access levels
│   ├── Protocols/               # 9 bridge protocols (DI interfaces)
│   ├── Bridges/                 # 10 concrete bridge implementations
│   └── Tools/                   # 10 tool modules + cross-app + handler utilities
│
├── MacOSLocalMCPAdmin/               # SwiftUI admin app
│   ├── MacOSLocalMCPAdminApp.swift   # App entry point
│   ├── AppState.swift           # Shared observable state
│   ├── Models/                  # Config, activity, status models
│   ├── Services/                # File-based services (monitor, config, feed)
│   └── Views/                   # 5 detail views + sidebar
│
Tests/
├── MacOSLocalMCPTests/               # Server tests (763 tests)
└── MacOSLocalMCPAdminTests/          # Admin app tests (48 tests)
```

### Design Principles

- **Protocol-based DI** — every bridge has a protocol; tools depend on protocols, never concrete types
- **TDD** — all 811 tests written first, implementation follows
- **Zero network** — no `URLSession` anywhere in the codebase
- **Zero dependencies** — only Swift stdlib and Apple system frameworks
- **No force unwraps** — no `!` in production code
- **Confirmation enforcement** — destructive tools enforce `confirmation: true` at both the tool layer and server layer

---

## Uninstall

```bash
bash uninstall.sh
```

This removes the binary and optionally the config directory. Also removes `/Applications/macOS Local MCP Server.app` if installed.

---

## Security

- **Local only** — the server communicates exclusively over stdio. No ports opened, no HTTP server, no cloud relay. Each MCP client spawns its own isolated subprocess.
- **No telemetry** — nothing is sent anywhere. All data stays on your Mac.
- **No dependencies** — no third-party Swift packages. The attack surface is the Swift stdlib and Apple frameworks.
- **Default deny** — all modules ship read-only. Write access must be explicitly enabled per module.
- **Confirmation gates** — thirteen high-impact tools require explicit `confirmation: true` before executing.
- **Injection prevention** — AppleScript inputs are sanitized (CR/LF stripping), SQL queries use quote doubling, Spotlight queries are sanitized, shell commands use `Process` with separate arguments (no interpolation).
- **Path traversal protection** — file operations block access to system directories (`/System`, `/Library`, `/usr`, `/bin`, `/sbin`, `/etc`, `/var`).
- **Restrictive file permissions** — all runtime files (config, logs, heartbeat, PID) are created with `0o700` directories and `0o600` files.
- **macOS permissions** — the server runs under your user account and respects macOS permission prompts for each app.

---

## License

MIT

---

<p align="center">
  <em>Built with Claude Code by a multi-agent team of specialized engineers.</em>
</p>
