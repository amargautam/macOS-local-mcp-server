import XCTest
@testable import MacOSLocalMCPAdmin

final class PermissionCheckerTests: XCTestCase {

    // MARK: - checkAll

    func test_checkAll_returnsEntryForEachKnownModule() {
        let checker = PermissionChecker()
        let results = checker.checkAll()
        let expectedModules = Set(ModuleConfig.allModuleNames.map { $0.name })
        let resultModules = Set(results.map { $0.moduleName })
        XCTAssertEqual(expectedModules, resultModules)
    }

    func test_checkAll_allEntriesHaveDisplayNames() {
        let checker = PermissionChecker()
        let results = checker.checkAll()
        for entry in results {
            XCTAssertFalse(entry.displayName.isEmpty, "Module \(entry.moduleName) has no display name")
        }
    }

    func test_checkAll_returnsValidStatuses() {
        let checker = PermissionChecker()
        let results = checker.checkAll()
        let valid: Set<PermissionStatus> = [.authorized, .denied, .notDetermined, .restricted]
        for entry in results {
            XCTAssertTrue(valid.contains(entry.status), "Unexpected status for \(entry.moduleName)")
        }
    }

    // MARK: - checkPermission(for:)

    func test_checkPermission_returnsValidStatus_forEachModule() {
        let checker = PermissionChecker()
        for (name, _) in ModuleConfig.allModuleNames {
            let status = checker.checkPermission(for: name)
            let valid: Set<PermissionStatus> = [.authorized, .denied, .notDetermined, .restricted]
            XCTAssertTrue(valid.contains(status), "Unexpected status for module \(name)")
        }
    }

    func test_checkPermission_returnsNotDetermined_forUnknownModule() {
        let checker = PermissionChecker()
        let status = checker.checkPermission(for: "completely_unknown_module_xyz")
        XCTAssertEqual(status, .notDetermined)
    }
}
