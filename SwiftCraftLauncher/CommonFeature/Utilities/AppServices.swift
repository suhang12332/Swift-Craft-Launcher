//
//  AppServices.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit

/// A global dependency container that manages shared service instances.
enum AppServices {
    struct Dependencies {
        var errorHandler: GlobalErrorHandler?

        var appCacheManager: AppCacheManager?
        var cacheCalculator: CacheCalculator?
        var cacheInfoManager: CacheInfoManager?

        var modScanner: ModScanner?
        var modCacheManager: ModCacheManager?
        var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry?
        var modInstallationCache: ModScanner.ModInstallationCache?
        var directoryHashCache: ModScanner.DirectoryHashCache?

        var windowManager: WindowManager?
        var windowDataStore: WindowDataStore?
        var iconRefreshNotifier: IconRefreshNotifier?
        var gameDialogsPresenter: GameDialogsPresenter?
        var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter?
        var openURLModPackImportPresenter: OpenURLModPackImportPresenter?

        var gameProcessManager: GameProcessManager?
        var gameStatusManager: GameStatusManager?
        var gameLogCollector: GameLogCollector?
        var gameActionManager: GameActionManager?

        var announcementStateManager: AnnouncementStateManager?
        var generalSettingsManager: GeneralSettingsManager?
        var gameSettingsManager: GameSettingsManager?
        var playerSettingsManager: PlayerSettingsManager?
        var playerDataManager: PlayerDataManager?
        var selectedGameManager: SelectedGameManager?
        var themeManager: ThemeManager?
        var languageManager: LanguageManager?

        var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator?

        var gitHubService: GitHubService?
        var minecraftAuthService: MinecraftAuthService?
        var yggdrasilAuthService: YggdrasilAuthService?
        var ipLocationService: IPLocationService?

        var javaManager: JavaManager?
        var javaRuntimeService: JavaRuntimeService?
        var javaDownloadManager: JavaDownloadManager?

        var aiSettingsManager: AISettingsManager?
        var aiChatManager: AIChatManager?
        var sparkleUpdateService: SparkleUpdateService?

        var serverAddressService: ServerAddressService?
        var litematicaService: LitematicaService?
        var premiumAccountFlagManager: PremiumAccountFlagManager?
        var minecraftFriendsService: MinecraftFriendsService?
    }

    private static let lock = NSRecursiveLock()
    private static var dependencies = Dependencies()
    private static var frozen = false

    private static let defaultMinecraftFriendsService = MinecraftFriendsService()

    static var isFrozen: Bool {
        lock.withLock { frozen }
    }

    /// Returns a MainActor-isolated shared instance, avoiding lock-related thread switches.
    private static func sharedOnMainActor<T>(_ factory: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(factory)
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(factory)
        }
    }

    /// Configures dependencies during app startup or testing.
    static func configure(_ updates: (inout Dependencies) -> Void) {
        lock.withLock {
            precondition(!frozen, "AppServices has been frozen and can no longer be reconfigured.")
            updates(&dependencies)
        }
    }

    /// Freezes dependencies to prevent concurrent hot-swapping after launch.
    static func freeze() {
        lock.withLock {
            frozen = true
        }
    }

    static var errorHandler: GlobalErrorHandler { lock.withLock { dependencies.errorHandler ?? .shared } }

    static var appCacheManager: AppCacheManager { lock.withLock { dependencies.appCacheManager ?? .shared } }
    static var cacheCalculator: CacheCalculator { lock.withLock { dependencies.cacheCalculator ?? .shared } }
    static var cacheInfoManager: CacheInfoManager {
        if let injected = lock.withLock({ dependencies.cacheInfoManager }) {
            return injected
        }
        return sharedOnMainActor { CacheInfoManager.shared }
    }

    static var modScanner: ModScanner { lock.withLock { dependencies.modScanner ?? .shared } }
    static var modCacheManager: ModCacheManager { lock.withLock { dependencies.modCacheManager ?? .shared } }
    static var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry { lock.withLock { dependencies.modDirectoryWatcherRegistry ?? .shared } }
    static var modInstallationCache: ModScanner.ModInstallationCache { lock.withLock { dependencies.modInstallationCache ?? .shared } }
    static var directoryHashCache: ModScanner.DirectoryHashCache { lock.withLock { dependencies.directoryHashCache ?? .shared } }

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
    static var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter {
        if let injected = lock.withLock({ dependencies.authlibInjectorMissingPresenter }) {
            return injected
        }
        return sharedOnMainActor { AuthlibInjectorMissingPresenter.shared }
    }
    static var openURLModPackImportPresenter: OpenURLModPackImportPresenter {
        if let injected = lock.withLock({ dependencies.openURLModPackImportPresenter }) {
            return injected
        }
        return sharedOnMainActor { OpenURLModPackImportPresenter.shared }
    }

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

    static var announcementStateManager: AnnouncementStateManager {
        if let injected = lock.withLock({ dependencies.announcementStateManager }) {
            return injected
        }
        return sharedOnMainActor { AnnouncementStateManager.shared }
    }
    static var generalSettingsManager: GeneralSettingsManager { lock.withLock { dependencies.generalSettingsManager ?? .shared } }
    static var gameSettingsManager: GameSettingsManager { lock.withLock { dependencies.gameSettingsManager ?? .shared } }
    static var playerSettingsManager: PlayerSettingsManager { lock.withLock { dependencies.playerSettingsManager ?? .shared } }
    static var playerDataManager: PlayerDataManager { lock.withLock { dependencies.playerDataManager ?? .shared } }
    static var selectedGameManager: SelectedGameManager { lock.withLock { dependencies.selectedGameManager ?? .shared } }
    static var themeManager: ThemeManager {
        if let injected = lock.withLock({ dependencies.themeManager }) {
            return injected
        }
        return sharedOnMainActor { ThemeManager.shared }
    }
    static var languageManager: LanguageManager { lock.withLock { dependencies.languageManager ?? .shared } }

    static var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator {
        if let injected = lock.withLock({ dependencies.minecraftFriendsPresencePollingCoordinator }) {
            return injected
        }
        return sharedOnMainActor { MinecraftFriendsPresencePollingCoordinator.shared }
    }

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

    static var javaManager: JavaManager { lock.withLock { dependencies.javaManager ?? .shared } }
    static var javaRuntimeService: JavaRuntimeService { lock.withLock { dependencies.javaRuntimeService ?? .shared } }
    static var javaDownloadManager: JavaDownloadManager {
        if let injected = lock.withLock({ dependencies.javaDownloadManager }) {
            return injected
        }
        return sharedOnMainActor { JavaDownloadManager.shared }
    }

    static var aiSettingsManager: AISettingsManager { lock.withLock { dependencies.aiSettingsManager ?? .shared } }
    static var aiChatManager: AIChatManager {
        if let injected = lock.withLock({ dependencies.aiChatManager }) {
            return injected
        }
        return sharedOnMainActor { AIChatManager.shared }
    }
    static var sparkleUpdateService: SparkleUpdateService { lock.withLock { dependencies.sparkleUpdateService ?? .shared } }

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
