//
//  UIContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import MinecraftFriendsKit
import SwiftUI

@Observable
final class UIContainer {
    // Window & UI

    private let _windowManager = MainActorLazyContainer { WindowManager() }
    @MainActor var windowManager: WindowManager { _windowManager.value() }

    private let _windowDataStore = MainActorLazyContainer { WindowDataStore() }
    @MainActor var windowDataStore: WindowDataStore { _windowDataStore.value() }

    private let _iconRefreshNotifier = MainActorLazyContainer { IconRefreshNotifier() }
    @MainActor var iconRefreshNotifier: IconRefreshNotifier { _iconRefreshNotifier.value() }

    private let _gameDialogsPresenter = MainActorLazyContainer { GameDialogsPresenter() }
    @MainActor var gameDialogsPresenter: GameDialogsPresenter { _gameDialogsPresenter.value() }

    private let _authlibInjectorMissingPresenter = MainActorLazyContainer { AuthlibInjectorMissingPresenter() }
    @MainActor var authlibInjectorMissingPresenter: AuthlibInjectorMissingPresenter {
        _authlibInjectorMissingPresenter.value()
    }

    private let _memoryPressureAlertPresenter = MainActorLazyContainer { MemoryPressureAlertPresenter() }
    @MainActor var memoryPressureAlertPresenter: MemoryPressureAlertPresenter {
        _memoryPressureAlertPresenter.value()
    }

    private let _openURLModPackImportPresenter = MainActorLazyContainer { OpenURLModPackImportPresenter() }
    @MainActor var openURLModPackImportPresenter: OpenURLModPackImportPresenter {
        _openURLModPackImportPresenter.value()
    }

    // Settings

    private let _announcementStateManager = MainActorLazyContainer { AnnouncementStateManager() }
    @MainActor var announcementStateManager: AnnouncementStateManager {
        _announcementStateManager.value()
    }

    private let _generalSettingsManager = LazyContainer { GeneralSettingsManager() }
    var generalSettingsManager: GeneralSettingsManager { _generalSettingsManager.value() }

    private let _gameSettingsManager = LazyContainer { GameSettingsManager() }
    var gameSettingsManager: GameSettingsManager { _gameSettingsManager.value() }

    private let _playerSettingsManager = LazyContainer { PlayerSettingsManager() }
    var playerSettingsManager: PlayerSettingsManager { _playerSettingsManager.value() }

    private let _playerDataManager = LazyContainer { PlayerDataManager() }
    var playerDataManager: PlayerDataManager { _playerDataManager.value() }

    private let _themeManager = LazyContainer { ThemeManager() }
    var themeManager: ThemeManager { _themeManager.value() }

    private let _languageManager = LazyContainer { LanguageManager() }
    var languageManager: LanguageManager { _languageManager.value() }

    private let _aiSettingsManager = LazyContainer { AISettingsManager() }
    var aiSettingsManager: AISettingsManager { _aiSettingsManager.value() }

    // Minecraft Friends

    private let _minecraftFriendsPresencePollingCoordinator = MainActorLazyContainer { MinecraftFriendsPresencePollingCoordinator() }
    @MainActor var minecraftFriendsPresencePollingCoordinator: MinecraftFriendsPresencePollingCoordinator {
        _minecraftFriendsPresencePollingCoordinator.value()
    }

    private let _minecraftFriendsService = LazyContainer { MinecraftFriendsService() }
    var minecraftFriendsService: MinecraftFriendsService {
        _minecraftFriendsService.value()
    }

    // AI Chat

    private let _aiChatManager = MainActorLazyContainer { AIChatManager() }
    @MainActor var aiChatManager: AIChatManager { _aiChatManager.value() }
}
