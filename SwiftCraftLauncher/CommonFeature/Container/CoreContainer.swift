//
//  CoreContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// `@unchecked Sendable`: immutable container; services are created through
/// thread-safe `@Lazy` / `@MainActorLazy` wrappers.
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

    @MainActorLazy var gameProcessManager: GameProcessManager = .init()
    @MainActorLazy var gameStatusManager: GameStatusManager = .init()
    @Lazy var gameLogCollector: GameLogCollector = .init()
    @MainActorLazy var gameActionManager: GameActionManager = .init()

    // Favorites

    @MainActorLazy var favoriteStore: FavoriteStore = .init()

    // Settings core

    @Lazy var selectedGameManager: SelectedGameManager = .init()
}
