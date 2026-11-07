//
//  UIContainer.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

final class UIContainer: @unchecked Sendable {
    // Window & UI

    @MainActorLazy var windowManager: WindowManager = .init()
    @MainActorLazy var iconRefreshNotifier: IconRefreshNotifier = .init()
    @MainActorLazy var gameDialogsPresenter: GameDialogsPresenter = .init()
    @MainActorLazy var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter = .init()
    @MainActorLazy var memoryPressureAlertPresenter: MemoryPressureAlertPresenter = .init()
    @MainActorLazy var openURLModPackImportPresenter: OpenURLModPackImportPresenter = .init()

    // Settings

    @MainActorLazy var announcementStateManager: AnnouncementStateManager = .init()
    @Lazy var generalSettingsManager: GeneralSettingsManager = .init()
    @Lazy var gameSettingsManager: GameSettingsManager = .init()
    @Lazy var playerSettingsManager: PlayerSettingsManager = .init()
    @Lazy var playerDataManager: PlayerDataManager = .init()
    @MainActorLazy var themeManager: ThemeManager = .init()
    @Lazy var languageManager: LanguageManager = .init()

    // Minecraft Friends

    @MainActorLazy var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator = .init()
    @Lazy var minecraftFriendsService: MinecraftFriendsService = .init()
}
