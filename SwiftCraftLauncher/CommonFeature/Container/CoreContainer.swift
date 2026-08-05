//
//  CoreContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

final class CoreContainer: @unchecked Sendable {
    // Error handling

    @Lazy var errorHandler: GlobalErrorHandler = .init()

    // Cache

    @Lazy var appCacheManager: AppCacheManager = .init()
    @Lazy var cacheCalculator: CacheCalculator = .init()
    @Lazy var cacheInfoManager: CacheInfoManager = .init()

    // Mods

    @Lazy var modScanner: ModScanner = .init()
    @Lazy var modCacheManager: ModCacheManager = .init()
    @Lazy var modDirectoryWatcherRegistry: ModDirectoryWatcherRegistry = .init()
    @Lazy var modInstallationCache: ModScanner.ModInstallationCache = .init()
    @Lazy var directoryHashCache: ModScanner.DirectoryHashCache = .init()

    // Game

    @Lazy var gameProcessManager: GameProcessManager = .init()
    @Lazy var gameStatusManager: GameStatusManager = .init()
    @Lazy var gameLogCollector: GameLogCollector = .init()
    @Lazy var gameActionManager: GameActionManager = .init()

    // Favorites

    @Lazy var favoriteStore: FavoriteStore = .init()

    // Settings core

    @Lazy var selectedGameManager: SelectedGameManager = .init()
}
