import Foundation
import MinecraftFriendsKit

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
        var minecraftFriendsService: MinecraftFriendsService?
    }

    private static let lock = NSRecursiveLock()
    private static var dependencies = Dependencies()
    private static var frozen = false

    private static let defaultMinecraftFriendsService = MinecraftFriendsService()

    static var isFrozen: Bool {
        lock.withLock { frozen }
    }

    /// 获取 MainActor 隔离的 shared 单例（不在持锁状态下切线程，避免优先级反转/死锁风险）。
    private static func sharedOnMainActor<T>(_ factory: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(factory)
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(factory)
        }
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
        if let injected = lock.withLock({ dependencies.windowManager }) {
            return injected
        }
        return sharedOnMainActor { WindowManager.shared }
    }
    static var windowDataStore: WindowDataStore {
        if let injected = lock.withLock({ dependencies.windowDataStore }) {
            return injected
        }
        return sharedOnMainActor { WindowDataStore.shared }
    }
    static var iconRefreshNotifier: IconRefreshNotifier { lock.withLock { dependencies.iconRefreshNotifier ?? .shared } }
    static var gameDialogsPresenter: GameDialogsPresenter {
        if let injected = lock.withLock({ dependencies.gameDialogsPresenter }) {
            return injected
        }
        return sharedOnMainActor { GameDialogsPresenter.shared }
    }
    static var openURLModPackImportPresenter: OpenURLModPackImportPresenter {
        if let injected = lock.withLock({ dependencies.openURLModPackImportPresenter }) {
            return injected
        }
        return sharedOnMainActor { OpenURLModPackImportPresenter.shared }
    }

    // MARK: - Game orchestration
    static var gameProcessManager: GameProcessManager { lock.withLock { dependencies.gameProcessManager ?? .shared } }
    static var gameStatusManager: GameStatusManager { lock.withLock { dependencies.gameStatusManager ?? .shared } }
    static var gameLogCollector: GameLogCollector {
        if let injected = lock.withLock({ dependencies.gameLogCollector }) {
            return injected
        }
        return sharedOnMainActor { GameLogCollector.shared }
    }
    static var gameActionManager: GameActionManager {
        if let injected = lock.withLock({ dependencies.gameActionManager }) {
            return injected
        }
        return sharedOnMainActor { GameActionManager.shared }
    }

    // MARK: - Settings / state
    static var announcementStateManager: AnnouncementStateManager {
        if let injected = lock.withLock({ dependencies.announcementStateManager }) {
            return injected
        }
        return sharedOnMainActor { AnnouncementStateManager.shared }
    }
    static var generalSettingsManager: GeneralSettingsManager { lock.withLock { dependencies.generalSettingsManager ?? .shared } }
    static var gameSettingsManager: GameSettingsManager { lock.withLock { dependencies.gameSettingsManager ?? .shared } }
    static var playerSettingsManager: PlayerSettingsManager { lock.withLock { dependencies.playerSettingsManager ?? .shared } }
    static var selectedGameManager: SelectedGameManager { lock.withLock { dependencies.selectedGameManager ?? .shared } }
    static var languageManager: LanguageManager { lock.withLock { dependencies.languageManager ?? .shared } }

    // MARK: - External services
    static var gitHubService: GitHubService {
        if let injected = lock.withLock({ dependencies.gitHubService }) {
            return injected
        }
        return sharedOnMainActor { GitHubService.shared }
    }
    static var minecraftAuthService: MinecraftAuthService { lock.withLock { dependencies.minecraftAuthService ?? .shared } }
    static var yggdrasilAuthService: YggdrasilAuthService { lock.withLock { dependencies.yggdrasilAuthService ?? .shared } }
    static var ipLocationService: IPLocationService {
        if let injected = lock.withLock({ dependencies.ipLocationService }) {
            return injected
        }
        return sharedOnMainActor { IPLocationService.shared }
    }

    // MARK: - Downloads / runtime
    static var javaManager: JavaManager { lock.withLock { dependencies.javaManager ?? .shared } }
    static var javaRuntimeService: JavaRuntimeService { lock.withLock { dependencies.javaRuntimeService ?? .shared } }
    static var javaDownloadManager: JavaDownloadManager {
        if let injected = lock.withLock({ dependencies.javaDownloadManager }) {
            return injected
        }
        return sharedOnMainActor { JavaDownloadManager.shared }
    }

    // MARK: - Feature managers
    static var aiSettingsManager: AISettingsManager { lock.withLock { dependencies.aiSettingsManager ?? .shared } }
    static var aiChatManager: AIChatManager {
        if let injected = lock.withLock({ dependencies.aiChatManager }) {
            return injected
        }
        return sharedOnMainActor { AIChatManager.shared }
    }
    static var sparkleUpdateService: SparkleUpdateService { lock.withLock { dependencies.sparkleUpdateService ?? .shared } }

    // MARK: - Misc
    static var serverAddressService: ServerAddressService {
        if let injected = lock.withLock({ dependencies.serverAddressService }) {
            return injected
        }
        return sharedOnMainActor { ServerAddressService.shared }
    }
    static var litematicaService: LitematicaService {
        if let injected = lock.withLock({ dependencies.litematicaService }) {
            return injected
        }
        return sharedOnMainActor { LitematicaService.shared }
    }
    static var premiumAccountFlagManager: PremiumAccountFlagManager {
        if let injected = lock.withLock({ dependencies.premiumAccountFlagManager }) {
            return injected
        }
        return sharedOnMainActor { PremiumAccountFlagManager.shared }
    }
    static var gameIconCache: GameIconCache { lock.withLock { dependencies.gameIconCache ?? .shared } }

    static var minecraftFriendsService: MinecraftFriendsService {
        lock.withLock { dependencies.minecraftFriendsService } ?? defaultMinecraftFriendsService
    }
}
private extension NSLocking {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
