//
//  SystemContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit

/// System layer for IO heavy / network / runtime operations.
/// `@unchecked Sendable`: immutable container; services are created through
/// thread-safe `@Lazy` / `@MainActorLazy` wrappers.
final class SystemContainer: @unchecked Sendable {
    // Authentication & Network

    @Lazy var gitHubService: GitHubService = .init()
    @MainActorLazy var minecraftAuthService: MinecraftAuthService = .init()
    @MainActorLazy var yggdrasilAuthService: YggdrasilAuthService = .init()
    @Lazy var ipLocationService: IPLocationService = .init()

    // Java

    @Lazy var javaManager: JavaManager = .init()
    @Lazy var javaRuntimeService: JavaRuntimeService = .init()
    @Lazy var javaRuntimeDownloader: JavaRuntimeDownloader = .init()
    @MainActorLazy var javaDownloadManager: JavaDownloadManager = .init()

    // Utilities

    @Lazy var sparkleUpdateService: SparkleUpdateService = .init()
    @Lazy var serverAddressService: ServerAddressService = .init()
    @Lazy var litematicaService: LitematicaService = .init()
    @Lazy var premiumAccountFlagManager: PremiumAccountFlagManager = .init()
}
