import SwiftUI
import Combine

/// Shared application state injected as an EnvironmentObject.
/// All services read from the filesystem; this object coordinates
/// refresh cycles and publishes updates to the SwiftUI views.
final class AppState: ObservableObject {

    // MARK: - Services (protocol-based DI)

    private let serverMonitor: any ServerMonitoring
    private let activityFeedService: any ActivityFeedProviding
    private let configService: any ConfigServicing
    private let permissionChecker: any PermissionChecking

    // MARK: - Published state

    @Published var serverStatus: ServerStatus = .notConfigured
    @Published var recentActivity: [ActivityEntry] = []
    @Published var activityCount: Int = 0
    @Published var config: AppConfig = .defaults
    @Published var permissions: [ModulePermission] = []
    @Published var modules: [ModuleConfig] = []

    // MARK: - Refresh timer

    private var refreshTimer: AnyCancellable?

    // MARK: - Init

    init(
        serverMonitor: any ServerMonitoring = ServerMonitor(),
        activityFeedService: any ActivityFeedProviding = ActivityFeedService(),
        configService: any ConfigServicing = ConfigService(),
        permissionChecker: any PermissionChecking = PermissionChecker()
    ) {
        self.serverMonitor = serverMonitor
        self.activityFeedService = activityFeedService
        self.configService = configService
        self.permissionChecker = permissionChecker

        refresh()
        startRefreshTimer()
    }

    // MARK: - Public API

    /// Reload all state from disk immediately.
    func refresh() {
        refreshServerStatus()
        refreshActivity()
        refreshConfig()
        refreshPermissions()
    }

    /// Toggle a module's enabled state and persist to disk.
    func setModuleEnabled(_ moduleName: String, enabled: Bool) {
        do {
            try configService.setModuleEnabled(moduleName, enabled: enabled)
            refreshConfig()
        } catch {
            refreshConfig()
        }
    }

    /// Set read/write access for a module and persist to disk.
    func setModuleAccess(_ moduleName: String, read: Bool, write: Bool) {
        do {
            try configService.setModuleAccess(moduleName, read: read, write: write)
            refreshConfig()
        } catch {
            refreshConfig()
        }
    }

    /// Save the full config and refresh state.
    func saveConfig(_ config: AppConfig) {
        do {
            try configService.saveConfig(config)
            refreshConfig()
        } catch {
            refreshConfig()
        }
    }

    // MARK: - Private

    private func startRefreshTimer() {
        refreshTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    private func refreshServerStatus() {
        if serverMonitor.isActive(), let pid = serverMonitor.pid() {
            serverStatus = .active(pid: pid)
        } else if serverMonitor.isConfigured() {
            serverStatus = .configured
        } else {
            serverStatus = .notConfigured
        }
    }

    private func refreshActivity() {
        recentActivity = activityFeedService.loadEntries(limit: 50)
        activityCount = activityFeedService.entriesCount()
    }

    private func refreshConfig() {
        config = configService.loadConfig()
        modules = ModuleConfig.allModuleNames.map { (name, displayName) in
            let access = config.enabledModules[name] ?? .allDisabled
            return ModuleConfig(
                name: name,
                displayName: displayName,
                readEnabled: access.read,
                writeEnabled: access.write
            )
        }
    }

    private func refreshPermissions() {
        permissions = permissionChecker.checkAll()
    }
}
