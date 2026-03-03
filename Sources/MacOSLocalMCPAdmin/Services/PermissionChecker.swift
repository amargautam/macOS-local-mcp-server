import Foundation
import EventKit
import Contacts
import SQLite3

// MARK: - Protocol

/// Checks macOS permission status for each macOS Local MCP module.
public protocol PermissionChecking {
    /// Returns the permission status for a single named module.
    func checkPermission(for module: String) -> PermissionStatus
    /// Returns permission status for all known modules.
    func checkAll() -> [ModulePermission]
}

// MARK: - Concrete Implementation

/// Queries framework-level authorization APIs and the user TCC database
/// to determine whether the MCP server has permission to use each
/// bridged Apple framework.
public final class PermissionChecker: PermissionChecking {

    private let binaryPath: String

    public init(binaryPath: String? = nil) {
        self.binaryPath = binaryPath ?? ServerMonitor.defaultBinaryPath
    }

    // MARK: - PermissionChecking

    public func checkPermission(for module: String) -> PermissionStatus {
        switch module {
        case "reminders":
            return mapEKStatus(EKEventStore.authorizationStatus(for: .reminder))
        case "calendar":
            return mapEKStatus(EKEventStore.authorizationStatus(for: .event))
        case "contacts":
            return mapCNStatus(CNContactStore.authorizationStatus(for: .contacts))
        case "mail":
            return checkTCCAutomation(targetApp: "com.apple.mail")
        case "messages":
            return checkTCCAutomation(targetApp: "com.apple.MobileSMS")
        case "notes":
            return checkTCCAutomation(targetApp: "com.apple.Notes")
        case "safari":
            return checkTCCAutomation(targetApp: "com.apple.Safari")
        case "finder":
            return checkTCCService("kTCCServiceSystemPolicyDesktopFolder")
        case "shortcuts":
            return checkTCCAutomation(targetApp: "com.apple.shortcuts")
        case "system":
            return checkTCCService("kTCCServiceAccessibility")
        default:
            return .notDetermined
        }
    }

    public func checkAll() -> [ModulePermission] {
        return ModuleConfig.allModuleNames.map { (name, displayName) in
            ModulePermission(
                moduleName: name,
                displayName: displayName,
                status: checkPermission(for: name),
                note: noteForModule(name)
            )
        }
    }

    // MARK: - Private

    private func mapEKStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    private func mapCNStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    /// Check TCC for an AppleEvents automation permission targeting a specific app.
    private func checkTCCAutomation(targetApp: String) -> PermissionStatus {
        return queryTCC(
            service: "kTCCServiceAppleEvents",
            client: binaryPath,
            indirectObject: targetApp
        )
    }

    /// Check TCC for a non-automation service (e.g. Desktop folder, Accessibility).
    private func checkTCCService(_ service: String) -> PermissionStatus {
        return queryTCC(service: service, client: binaryPath, indirectObject: nil)
    }

    /// SQLite transient destructor — tells SQLite to copy the string immediately.
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Query the user's TCC.db for a specific permission entry.
    /// auth_value: 0 = denied, 2 = authorized.
    private func queryTCC(service: String, client: String, indirectObject: String?) -> PermissionStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return .notDetermined
        }
        defer { sqlite3_close(db) }

        let sql: String
        if let target = indirectObject {
            sql = "SELECT auth_value FROM access WHERE service = ?1 AND client = ?2 AND indirect_object_identifier = ?3 LIMIT 1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .notDetermined
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, service, -1, Self.sqliteTransient)
            sqlite3_bind_text(stmt, 2, client, -1, Self.sqliteTransient)
            sqlite3_bind_text(stmt, 3, target, -1, Self.sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let authValue = sqlite3_column_int(stmt, 0)
                return authValue == 2 ? .authorized : .denied
            }
            return .notDetermined
        } else {
            sql = "SELECT auth_value FROM access WHERE service = ?1 AND client = ?2 LIMIT 1"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return .notDetermined
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, service, -1, Self.sqliteTransient)
            sqlite3_bind_text(stmt, 2, client, -1, Self.sqliteTransient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let authValue = sqlite3_column_int(stmt, 0)
                return authValue == 2 ? .authorized : .denied
            }
            return .notDetermined
        }
    }

    private func noteForModule(_ module: String) -> String? {
        switch module {
        case "mail", "messages", "notes", "safari", "finder", "shortcuts":
            return "Grant access in System Settings > Privacy & Security > Automation"
        case "system":
            return "Grant access in System Settings > Privacy & Security > Accessibility"
        default:
            return nil
        }
    }
}
