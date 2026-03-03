import Foundation
import EventKit
import Contacts

// macOS Local MCP Server — Entry point
// Instantiates all bridges, wires up all tool handlers, and starts the JSON-RPC server.

let server = MCPServer()

// ── Bridges ──────────────────────────────────────────────────────────
// Each bridge is the concrete implementation behind a protocol.
// Tools depend only on protocols, never on these concrete types.

let eventKitBridge = EventKitBridge()           // RemindersProviding + CalendarProviding
let contactsBridge = ContactsBridge()           // ContactsProviding
let finderBridge = FinderBridge()               // FinderProviding
let mailBridge = MailBridge()                   // MailProviding
let notesBridge = NotesBridge()                 // NotesProviding
let messagesBridge = MessagesBridge()           // MessagesProviding
let safariBridge = SafariBridge()               // SafariProviding
let shortcutsBridge = ShortcutsBridge()         // ShortcutsProviding

// ── Tools ────────────────────────────────────────────────────────────
// Each tool module creates MCPToolHandler instances for its domain.

let remindersTool = RemindersTool(provider: eventKitBridge)
let calendarTool = CalendarTool(provider: eventKitBridge)
let contactsTool = ContactsTool(provider: contactsBridge)
let finderTool = FinderTool(provider: finderBridge)
let mailTool = MailTool(provider: mailBridge)
let notesTool = NotesTool(provider: notesBridge)
let messagesTool = MessagesTool(provider: messagesBridge)
let safariTool = SafariTool(provider: safariBridge)
let shortcutsTool = ShortcutsTool(provider: shortcutsBridge)
let crossAppTool = CrossAppTool(
    calendarProvider: eventKitBridge,
    contactsProvider: contactsBridge,
    mailProvider: mailBridge,
    messagesProvider: messagesBridge
)

// ── Register all handlers ────────────────────────────────────────────

server.toolRegistry.registerAll(remindersTool.createHandlers())
server.toolRegistry.registerAll(calendarTool.createHandlers())
server.toolRegistry.registerAll(contactsTool.createHandlers())
server.toolRegistry.registerAll(finderTool.createHandlers())
server.toolRegistry.registerAll(mailTool.createHandlers())
server.toolRegistry.registerAll(notesTool.createHandlers())
server.toolRegistry.registerAll(messagesTool.createHandlers())
server.toolRegistry.registerAll(safariTool.createHandlers())
server.toolRegistry.registerAll(shortcutsTool.createHandlers())
server.toolRegistry.registerAll(crossAppTool.createHandlers())

// ── Start server ─────────────────────────────────────────────────────

server.run()
