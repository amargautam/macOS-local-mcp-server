# macOS Local MCP Project

## What This Is
A local MCP server in Swift + a native SwiftUI admin app
that bridges Claude Desktop to Apple apps on macOS.

Read SPEC.md for the full specification.

## Build Commands
- Build: swift build
- Test: swift test
- Release build: swift build -c release
- Run server: .build/debug/macos-local-mcp

## Development Rules
- TDD: Write tests FIRST, always. No exceptions.
- swift test must pass before requesting code review.
- CODE REVIEW: No phase is complete without code-reviewer approval.
- SECURITY: security-reviewer agent runs in parallel with all
  code changes. Must pass before any commit. See below.
- Zero network: No URLSession anywhere in the codebase.
- Protocol-based DI: Every bridge has a protocol.
  Tools depend on protocols, not concrete bridges.
- Agents work only on their assigned modules.
- No force unwraps (!) in production code.
- Disk writes only to ~/.macos-local-mcp/ directory.

## Review Process
After every phase: implement → tests green → code-reviewer
reviews → fixes if needed → re-review → APPROVED → advance.
Never skip the review step.

## Security Review Process
The security-reviewer agent runs proactively and in parallel:
- Before tests: targeted scan on changed files
- After tests: full codebase scan
- Before any commit: full audit must PASS (no exceptions)
- On any new tool/bridge: scan for injection vectors

Spawn security-reviewer as a background agent whenever code
changes are made. It does not need to be asked — spawn it
proactively alongside test runs.

## Progress
Track in PROGRESS.md

## Phase Order
0. Foundation (protocol, config, activity logger, mocks)
1. Reminders + Calendar (EventKit)
2. Contacts
3. Finder + Spotlight
4. Mail
5. Notes
6. Messages
7. Safari
8. Shortcuts
9. Cross-App Workflows
10. Admin App
11. Install + Integration
