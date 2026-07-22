//
//  UIContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

final class UIContainer {
    // Window & UI

    @MainActorLazy var windowManager: WindowManager = .init()
    @MainActorLazy var windowDataStore: WindowDataStore = .init()
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
    @Lazy var themeManager: ThemeManager = .init()
    @Lazy var languageManager: LanguageManager = .init()
    @Lazy var aiSettingsManager: AISettingsManager = .init()

    // Minecraft Friends

    @MainActorLazy var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator = .init()
    @Lazy var minecraftFriendsService: MinecraftFriendsService = .init()

    // AI Chat

    @MainActorLazy var aiChatManager: AIChatManager = .init()
}
