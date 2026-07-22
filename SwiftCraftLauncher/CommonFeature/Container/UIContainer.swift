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

    @MainActorLazy var windowManager: WindowManager = WindowManager()
    @MainActorLazy var windowDataStore: WindowDataStore = WindowDataStore()
    @MainActorLazy var iconRefreshNotifier: IconRefreshNotifier = IconRefreshNotifier()
    @MainActorLazy var gameDialogsPresenter: GameDialogsPresenter = GameDialogsPresenter()
    @MainActorLazy var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter = AuthlibInjectorMissingPresenter()
    @MainActorLazy var memoryPressureAlertPresenter: MemoryPressureAlertPresenter = MemoryPressureAlertPresenter()
    @MainActorLazy var openURLModPackImportPresenter: OpenURLModPackImportPresenter = OpenURLModPackImportPresenter()

    // Settings

    @MainActorLazy var announcementStateManager: AnnouncementStateManager = AnnouncementStateManager()
    @Lazy var generalSettingsManager: GeneralSettingsManager = GeneralSettingsManager()
    @Lazy var gameSettingsManager: GameSettingsManager = GameSettingsManager()
    @Lazy var playerSettingsManager: PlayerSettingsManager = PlayerSettingsManager()
    @Lazy var playerDataManager: PlayerDataManager = PlayerDataManager()
    @Lazy var themeManager: ThemeManager = ThemeManager()
    @Lazy var languageManager: LanguageManager = LanguageManager()
    @Lazy var aiSettingsManager: AISettingsManager = AISettingsManager()

    // Minecraft Friends

    @MainActorLazy var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator = MinecraftFriendsPresencePollingCoordinator()
    @Lazy var minecraftFriendsService: MinecraftFriendsService = MinecraftFriendsService()

    // AI Chat

    @MainActorLazy var aiChatManager: AIChatManager = AIChatManager()
}
