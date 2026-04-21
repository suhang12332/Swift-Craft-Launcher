//
//  SwiftCraftLauncherApp.swift
//  Swift Craft Launcher
//
//  Created by su on 2025/5/30.
//
//  Swift Craft Launcher - A modern macOS Minecraft launcher
//
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
//  ADDITIONAL TERMS:
//  This program includes additional terms for source attribution and name usage.
//  See doc/ADDITIONAL_TERMS.md in the project root for details.

import SwiftUI
import UserNotifications
import Combine

@main
struct SwiftCraftLauncherApp: App {
    // MARK: - StateObjects
    @StateObject var playerListViewModel = PlayerListViewModel()
    @StateObject var gameRepository = GameRepository()
    @StateObject var gameLaunchUseCase = GameLaunchUseCase()
    @StateObject private var errorHandler: GlobalErrorHandler
    @StateObject private var sparkleUpdateService: SparkleUpdateService
    @StateObject var generalSettingsManager: GeneralSettingsManager
    @StateObject var themeManager: ThemeManager
    @StateObject var javaDownloadManager: JavaDownloadManager
    @StateObject private var skinSelectionStore = SkinSelectionStore()
    @ObservedObject private var gameDialogsPresenter: GameDialogsPresenter
    private let openURLModPackImportPresenter: OpenURLModPackImportPresenter
    private let windowDataStore: WindowDataStore
    private let aiChatManager: AIChatManager
    private let windowManager: WindowManager

    @Environment(\.openSettings)
    private var openSettings

    // MARK: - Notification Delegate
    private let notificationCenterDelegate = NotificationCenterDelegate()

    init() {
        _errorHandler = StateObject(wrappedValue: AppServices.errorHandler)
        _sparkleUpdateService = StateObject(wrappedValue: AppServices.sparkleUpdateService)
        _generalSettingsManager = StateObject(wrappedValue: AppServices.generalSettingsManager)
        _themeManager = StateObject(wrappedValue: AppServices.themeManager)
        _javaDownloadManager = StateObject(wrappedValue: AppServices.javaDownloadManager)
        _gameDialogsPresenter = ObservedObject(wrappedValue: AppServices.gameDialogsPresenter)
        self.openURLModPackImportPresenter = AppServices.openURLModPackImportPresenter
        self.windowDataStore = AppServices.windowDataStore
        self.aiChatManager = AppServices.aiChatManager
        self.windowManager = AppServices.windowManager

        Self.configureURLCache()
        Self.configureNotifications(delegate: notificationCenterDelegate)

        AppServices.freeze()
    }

    // MARK: - Body
    var body: some Scene {
        Window(Bundle.main.appName, id: WindowID.main.rawValue) {
            mainWindowContent
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            SwiftCraftLauncherAppCommands(
                sparkleUpdateService: sparkleUpdateService,
                windowManager: windowManager,
                aiChatManager: aiChatManager
            )
        }

        Settings {
            settingsContent
        }

        // 应用窗口组
        appWindowGroups()
            .windowStyle(.titleBar)
            .applyRestorationBehaviorDisabled()
            .windowResizability(.contentSize)

        // 右上角的状态栏(可以显示图标的)
        MenuBarExtra(
            content: {
                MenuBarExtraContentView(
                    openSettings: { openSettings() },
                    openGameDeletion: { game in gameDialogsPresenter.requestGameDeletion(of: game) },
                    openModPackExport: { game in gameDialogsPresenter.presentModPackExport(for: game) }
                )
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
            },
            label: {
                Image("menu-png").resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
        )
    }

    // MARK: - Main Content
    private var mainWindowContent: some View {
        MainView()
            .environmentObject(playerListViewModel)
            .environmentObject(gameRepository)
            .environmentObject(gameLaunchUseCase)
            .preferredColorScheme(themeManager.currentColorScheme)
            .errorAlert()
            .windowOpener()
            .onOpenURL(perform: openURLModPackImportPresenter.handle)
            .onAppear(perform: cleanupWindowDataOnLaunch)
    }

    private var settingsContent: some View {
        SettingsView()
            .environmentObject(gameRepository)
            .preferredColorScheme(themeManager.currentColorScheme)
            .errorAlert()
    }

    // MARK: - Helpers
    private static func configureURLCache() {
        URLCache.shared = URLCache(
            memoryCapacity: AppConstants.URLCacheConfig.memoryCapacity,
            diskCapacity: AppConstants.URLCacheConfig.diskCapacity,
            diskPath: nil
        )
    }

    private static func configureNotifications(delegate: UNUserNotificationCenterDelegate) {
        // 设置通知中心代理，确保前台时也能展示 Banner
        UNUserNotificationCenter.current().delegate = delegate
        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }
    }

    private func cleanupWindowDataOnLaunch() {
        // 应用启动时清理所有窗口数据
        windowDataStore.cleanup(for: .aiChat)
        windowDataStore.cleanup(for: .skinPreview)
    }
}
