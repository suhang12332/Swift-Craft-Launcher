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

    @Lazy var gitHubService: GitHubService = GitHubService()
    @Lazy var minecraftAuthService: MinecraftAuthService = MinecraftAuthService()
    @Lazy var yggdrasilAuthService: YggdrasilAuthService = YggdrasilAuthService()
    @Lazy var ipLocationService: IPLocationService = IPLocationService()

    // Java

    @MainActorLazy var javaManager: JavaManager = JavaManager()
    @Lazy var javaRuntimeService: JavaRuntimeService = JavaRuntimeService()
    @Lazy var javaRuntimeDownloader: JavaRuntimeDownloader = JavaRuntimeDownloader()
    @Lazy var javaDownloadManager: JavaDownloadManager = JavaDownloadManager()

    // Utilities

    @Lazy var sparkleUpdateService: SparkleUpdateService = SparkleUpdateService()
    @Lazy var serverAddressService: ServerAddressService = ServerAddressService()
    @Lazy var litematicaService: LitematicaService = LitematicaService()
    @Lazy var premiumAccountFlagManager: PremiumAccountFlagManager = PremiumAccountFlagManager()
}
