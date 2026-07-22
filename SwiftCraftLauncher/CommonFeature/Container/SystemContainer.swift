//
//  SystemContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit
import Observation

/// System layer for IO heavy / network / runtime operations.
@Observable
final class SystemContainer {
    // Authentication & Network

    private let _gitHubService = LazyContainer { GitHubService() }
    var gitHubService: GitHubService { _gitHubService.value() }

    private let _minecraftAuthService = LazyContainer { MinecraftAuthService() }
    var minecraftAuthService: MinecraftAuthService { _minecraftAuthService.value() }

    private let _yggdrasilAuthService = LazyContainer { YggdrasilAuthService() }
    var yggdrasilAuthService: YggdrasilAuthService { _yggdrasilAuthService.value() }

    private let _ipLocationService = LazyContainer { IPLocationService() }
    var ipLocationService: IPLocationService { _ipLocationService.value() }

    // Java

    private let _javaManager = MainActorLazyContainer { JavaManager() }
    @MainActor var javaManager: JavaManager { _javaManager.value() }

    private let _javaRuntimeService = LazyContainer { JavaRuntimeService() }
    var javaRuntimeService: JavaRuntimeService { _javaRuntimeService.value() }

    private let _javaRuntimeDownloader = LazyContainer { JavaRuntimeDownloader() }
    var javaRuntimeDownloader: JavaRuntimeDownloader { _javaRuntimeDownloader.value() }

    private let _javaDownloadManager = LazyContainer { JavaDownloadManager() }
    var javaDownloadManager: JavaDownloadManager { _javaDownloadManager.value() }

    // Utilities

    private let _sparkleUpdateService = LazyContainer { SparkleUpdateService() }
    var sparkleUpdateService: SparkleUpdateService { _sparkleUpdateService.value() }

    private let _serverAddressService = LazyContainer { ServerAddressService() }
    var serverAddressService: ServerAddressService { _serverAddressService.value() }

    private let _litematicaService = LazyContainer { LitematicaService() }
    var litematicaService: LitematicaService { _litematicaService.value() }

    private let _premiumAccountFlagManager = LazyContainer { PremiumAccountFlagManager() }
    var premiumAccountFlagManager: PremiumAccountFlagManager {
        _premiumAccountFlagManager.value()
    }
}
