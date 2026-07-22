//
//  CoreContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

final class CoreContainer {
    // Error handling

    @Lazy var errorHandler: GlobalErrorHandler = GlobalErrorHandler()

    // Cache

    @Lazy var appCacheManager: AppCacheManager = AppCacheManager()
    @Lazy var cacheCalculator: CacheCalculator = CacheCalculator()
    @Lazy var cacheInfoManager: CacheInfoManager = CacheInfoManager()

    // Mods

    @Lazy var modScanner: ModScanner = ModScanner()
    @Lazy var modCacheManager: ModCacheManager = ModCacheManager()
    @Lazy var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry = ModDirectoryWatcherRegistry()
    @Lazy var modInstallationCache: ModScanner.ModInstallationCache = ModScanner.ModInstallationCache()
    @Lazy var directoryHashCache: ModScanner.DirectoryHashCache = ModScanner.DirectoryHashCache()

    // Game

    @Lazy var gameProcessManager: GameProcessManager = GameProcessManager()
    @Lazy var gameStatusManager: GameStatusManager = GameStatusManager()
    @Lazy var gameLogCollector: GameLogCollector = GameLogCollector()
    @Lazy var gameActionManager: GameActionManager = GameActionManager()

    // Favorites

    @Lazy var favoriteStore: FavoriteStore = FavoriteStore()

    // Settings core

    @Lazy var selectedGameManager: SelectedGameManager = SelectedGameManager()
}
