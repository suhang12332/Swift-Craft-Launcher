//
//  SystemContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit

/// System layer for IO heavy / network / runtime operations.
final class SystemContainer {
    // Authentication & Network

    @Lazy var gitHubService: GitHubService = .init()
    @Lazy var minecraftAuthService: MinecraftAuthService = .init()
    @Lazy var yggdrasilAuthService: YggdrasilAuthService = .init()
    @Lazy var ipLocationService: IPLocationService = .init()

    // Java

    @MainActorLazy var javaManager: JavaManager = .init()
    @Lazy var javaRuntimeService: JavaRuntimeService = .init()
    @Lazy var javaRuntimeDownloader: JavaRuntimeDownloader = .init()
    @Lazy var javaDownloadManager: JavaDownloadManager = .init()

    // Utilities

    @Lazy var sparkleUpdateService: SparkleUpdateService = .init()
    @Lazy var serverAddressService: ServerAddressService = .init()
    @Lazy var litematicaService: LitematicaService = .init()
    @Lazy var premiumAccountFlagManager: PremiumAccountFlagManager = .init()
}
