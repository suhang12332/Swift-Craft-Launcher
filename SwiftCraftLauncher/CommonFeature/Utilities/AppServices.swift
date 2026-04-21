import Foundation

/// 全局依赖容器
enum AppServices {
    struct Dependencies {
        // MARK: - Error handling
        var errorHandler: GlobalErrorHandler?

        // MARK: - Cache
        var appCacheManager: AppCacheManager?
        var cacheCalculator: CacheCalculator?

        // MARK: - Resource / scanning
        var modScanner: ModScanner?
        var modCacheManager: ModCacheManager?
        var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry?
        var modInstallationCache: ModScanner.ModInstallationCache?
        var directoryHashCache: ModScanner.DirectoryHashCache?

        // MARK: - Windowing
        var windowManager: WindowManager?
        var windowDataStore: WindowDataStore?
        var iconRefreshNotifier: IconRefreshNotifier?
        var gameDialogsPresenter: GameDialogsPresenter?
        var openURLModPackImportPresenter: OpenURLModPackImportPresenter?

        // MARK: - Game orchestration
        var gameProcessManager: GameProcessManager?
        var gameStatusManager: GameStatusManager?
        var gameLogCollector: GameLogCollector?
        var gameActionManager: GameActionManager?

        // MARK: - Settings / state
        var announcementStateManager: AnnouncementStateManager?
        var generalSettingsManager: GeneralSettingsManager?
        var gameSettingsManager: GameSettingsManager?
        var playerSettingsManager: PlayerSettingsManager?
        var selectedGameManager: SelectedGameManager?
        var themeManager: ThemeManager?
        var languageManager: LanguageManager?

        // MARK: - External services
        var gitHubService: GitHubService?
        var minecraftAuthService: MinecraftAuthService?
        var yggdrasilAuthService: YggdrasilAuthService?
        var ipLocationService: IPLocationService?

        // MARK: - Downloads / runtime
        var javaManager: JavaManager?
        var javaRuntimeService: JavaRuntimeService?
        var javaDownloadManager: JavaDownloadManager?

        // MARK: - Feature managers
        var aiSettingsManager: AISettingsManager?
        var aiChatManager: AIChatManager?
        var sparkleUpdateService: SparkleUpdateService?

        // MARK: - Misc
        var serverAddressService: ServerAddressService?
        var litematicaService: LitematicaService?
        var premiumAccountFlagManager: PremiumAccountFlagManager?
        var gameIconCache: GameIconCache?
    }

    private static let lock = NSRecursiveLock()
    private static var dependencies = Dependencies()
    private static var frozen = false

    static var isFrozen: Bool {
        lock.withLock { frozen }
    }

    /// 仅允许在应用启动阶段或测试阶段配置依赖。
    static func configure(_ updates: (inout Dependencies) -> Void) {
        lock.withLock {
            precondition(!frozen, "AppServices has been frozen and can no longer be reconfigured.")
            updates(&dependencies)
        }
    }

    /// 进入运行阶段后冻结依赖，避免并发场景下被热切换。
    static func freeze() {
        lock.withLock {
            frozen = true
        }
    }

    // MARK: - Error handling
    static var errorHandler: GlobalErrorHandler { lock.withLock { dependencies.errorHandler ?? .shared } }

    // MARK: - Cache
    static var appCacheManager: AppCacheManager { lock.withLock { dependencies.appCacheManager ?? .shared } }
    static var cacheCalculator: CacheCalculator { lock.withLock { dependencies.cacheCalculator ?? .shared } }

    // MARK: - Resource / scanning
    static var modScanner: ModScanner { lock.withLock { dependencies.modScanner ?? .shared } }
    static var modCacheManager: ModCacheManager { lock.withLock { dependencies.modCacheManager ?? .shared } }
    static var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry { lock.withLock { dependencies.modDirectoryWatcherRegistry ?? .shared } }
    static var modInstallationCache: ModScanner.ModInstallationCache { lock.withLock { dependencies.modInstallationCache ?? .shared } }
    static var directoryHashCache: ModScanner.DirectoryHashCache { lock.withLock { dependencies.directoryHashCache ?? .shared } }

    // MARK: - Windowing
    static var windowManager: WindowManager {
        lock.withLock {
            if let manager = dependencies.windowManager {
                return manager
            }
            return MainActor.assumeIsolated { WindowManager.shared }
        }
    }
    static var windowDataStore: WindowDataStore {
        lock.withLock {
            if let dataStore = dependencies.windowDataStore {
                return dataStore
            }
            return MainActor.assumeIsolated { WindowDataStore.shared }
        }
    }
    static var iconRefreshNotifier: IconRefreshNotifier { lock.withLock { dependencies.iconRefreshNotifier ?? .shared } }
    static var gameDialogsPresenter: GameDialogsPresenter {
        lock.withLock {
            if let presenter = dependencies.gameDialogsPresenter {
                return presenter
            }
            return MainActor.assumeIsolated { GameDialogsPresenter.shared }
        }
    }
    static var openURLModPackImportPresenter: OpenURLModPackImportPresenter {
        lock.withLock {
            if let presenter = dependencies.openURLModPackImportPresenter {
                return presenter
            }
            return MainActor.assumeIsolated { OpenURLModPackImportPresenter.shared }
        }
    }

    // MARK: - Game orchestration
    static var gameProcessManager: GameProcessManager { lock.withLock { dependencies.gameProcessManager ?? .shared } }
    static var gameStatusManager: GameStatusManager { lock.withLock { dependencies.gameStatusManager ?? .shared } }
    static var gameLogCollector: GameLogCollector {
        lock.withLock {
            if let collector = dependencies.gameLogCollector {
                return collector
            }
            return MainActor.assumeIsolated { GameLogCollector.shared }
        }
    }
    static var gameActionManager: GameActionManager {
        lock.withLock {
            if let manager = dependencies.gameActionManager {
                return manager
            }
            return MainActor.assumeIsolated { GameActionManager.shared }
        }
    }

    // MARK: - Settings / state
    static var announcementStateManager: AnnouncementStateManager {
        lock.withLock {
            if let manager = dependencies.announcementStateManager {
                return manager
            }
            return MainActor.assumeIsolated { AnnouncementStateManager.shared }
        }
    }
    static var generalSettingsManager: GeneralSettingsManager { lock.withLock { dependencies.generalSettingsManager ?? .shared } }
    static var gameSettingsManager: GameSettingsManager { lock.withLock { dependencies.gameSettingsManager ?? .shared } }
    static var playerSettingsManager: PlayerSettingsManager { lock.withLock { dependencies.playerSettingsManager ?? .shared } }
    static var selectedGameManager: SelectedGameManager { lock.withLock { dependencies.selectedGameManager ?? .shared } }
    static var themeManager: ThemeManager { lock.withLock { dependencies.themeManager ?? .shared } }
    static var languageManager: LanguageManager { lock.withLock { dependencies.languageManager ?? .shared } }

    // MARK: - External services
    static var gitHubService: GitHubService {
        lock.withLock {
            if let service = dependencies.gitHubService {
                return service
            }
            return MainActor.assumeIsolated { GitHubService.shared }
        }
    }
    static var minecraftAuthService: MinecraftAuthService { lock.withLock { dependencies.minecraftAuthService ?? .shared } }
    static var yggdrasilAuthService: YggdrasilAuthService { lock.withLock { dependencies.yggdrasilAuthService ?? .shared } }
    static var ipLocationService: IPLocationService {
        lock.withLock {
            if let service = dependencies.ipLocationService {
                return service
            }
            return MainActor.assumeIsolated { IPLocationService.shared }
        }
    }

    // MARK: - Downloads / runtime
    static var javaManager: JavaManager { lock.withLock { dependencies.javaManager ?? .shared } }
    static var javaRuntimeService: JavaRuntimeService { lock.withLock { dependencies.javaRuntimeService ?? .shared } }
    static var javaDownloadManager: JavaDownloadManager {
        lock.withLock {
            if let manager = dependencies.javaDownloadManager {
                return manager
            }
            return MainActor.assumeIsolated { JavaDownloadManager.shared }
        }
    }

    // MARK: - Feature managers
    static var aiSettingsManager: AISettingsManager { lock.withLock { dependencies.aiSettingsManager ?? .shared } }
    static var aiChatManager: AIChatManager {
        lock.withLock {
            if let manager = dependencies.aiChatManager {
                return manager
            }
            return MainActor.assumeIsolated { AIChatManager.shared }
        }
    }
    static var sparkleUpdateService: SparkleUpdateService { lock.withLock { dependencies.sparkleUpdateService ?? .shared } }

    // MARK: - Misc
    static var serverAddressService: ServerAddressService {
        lock.withLock {
            if let service = dependencies.serverAddressService {
                return service
            }
            return MainActor.assumeIsolated { ServerAddressService.shared }
        }
    }
    static var litematicaService: LitematicaService {
        lock.withLock {
            if let service = dependencies.litematicaService {
                return service
            }
            return MainActor.assumeIsolated { LitematicaService.shared }
        }
    }
    static var premiumAccountFlagManager: PremiumAccountFlagManager {
        lock.withLock {
            if let manager = dependencies.premiumAccountFlagManager {
                return manager
            }
            return MainActor.assumeIsolated { PremiumAccountFlagManager.shared }
        }
    }
    static var gameIconCache: GameIconCache { lock.withLock { dependencies.gameIconCache ?? .shared } }
}
private extension NSLocking {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
