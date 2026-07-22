//
//  CoreContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation

@Observable
final class CoreContainer {
    // Error handling

    private let _errorHandler = LazyContainer { GlobalErrorHandler() }
    var errorHandler: GlobalErrorHandler { _errorHandler.value() }

    // Cache

    private let _appCacheManager = LazyContainer { AppCacheManager() }
    var appCacheManager: AppCacheManager { _appCacheManager.value() }
    private let _cacheCalculator = LazyContainer { CacheCalculator() }
    var cacheCalculator: CacheCalculator { _cacheCalculator.value() }
    private let _cacheInfoManager = LazyContainer { CacheInfoManager() }
    var cacheInfoManager: CacheInfoManager { _cacheInfoManager.value() }

    // Mods

    private let _modScanner = LazyContainer { ModScanner() }
    var modScanner: ModScanner { _modScanner.value() }
    private let _modCacheManager = LazyContainer { ModCacheManager() }
    var modCacheManager: ModCacheManager { _modCacheManager.value() }
    private let _modDirectoryWatcherRegistry = LazyContainer { ModDirectoryWatcherRegistry() }
    var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry { _modDirectoryWatcherRegistry.value() }
    private let _modInstallationCache = LazyContainer { ModScanner.ModInstallationCache() }
    var modInstallationCache: ModScanner.ModInstallationCache { _modInstallationCache.value() }
    private let _directoryHashCache = LazyContainer { ModScanner.DirectoryHashCache() }
    var directoryHashCache: ModScanner.DirectoryHashCache { _directoryHashCache.value() }

    // Game

    private let _gameProcessManager = LazyContainer { GameProcessManager() }
    var gameProcessManager: GameProcessManager { _gameProcessManager.value() }
    private let _gameStatusManager = LazyContainer { GameStatusManager() }
    var gameStatusManager: GameStatusManager { _gameStatusManager.value() }
    private let _gameLogCollector = LazyContainer { GameLogCollector() }
    var gameLogCollector: GameLogCollector { _gameLogCollector.value() }
    private let _gameActionManager = LazyContainer { GameActionManager() }
    var gameActionManager: GameActionManager { _gameActionManager.value() }

    // Favorites

    private let _favoriteStore = LazyContainer { FavoriteStore() }
    var favoriteStore: FavoriteStore { _favoriteStore.value() }

    // Settings core

    private let _selectedGameManager = LazyContainer { SelectedGameManager() }
    var selectedGameManager: SelectedGameManager { _selectedGameManager.value() }
}
