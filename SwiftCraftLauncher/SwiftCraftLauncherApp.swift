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
    @StateObject var generalSettingsManager: GeneralSettingsManager
    @StateObject var themeManager: ThemeManager

    @Environment(\.openSettings)
    private var openSettings

    // MARK: - Notification Delegate
    private let notificationCenterDelegate = NotificationCenterDelegate()

    init() {
        _generalSettingsManager = StateObject(wrappedValue: AppServices.generalSettingsManager)
        _themeManager = StateObject(wrappedValue: AppServices.themeManager)

        Self.configureURLCache()
        Self.configureNotifications(delegate: notificationCenterDelegate)

        AppServices.freeze()
    }

    // MARK: - Body
    var body: some Scene {
        Window(Bundle.main.appName, id: WindowID.main.rawValue) {
            MainView()
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
                .environmentObject(AppServices.gameActionManager)
                .environmentObject(AppServices.gameStatusManager)
                .preferredColorScheme(themeManager.currentColorScheme)
                .errorAlert()
                .windowOpener()
                .onOpenURL { url in
                    AppServices.openURLModPackImportPresenter.handle(url: url)
                }
                .task {
                    AppServices.sparkleUpdateService.scheduleStartupCheckIfNeeded()
                }
                .onAppear(perform: cleanupWindowDataOnLaunch)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            SwiftCraftLauncherAppCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(gameRepository)
                .preferredColorScheme(themeManager.currentColorScheme)
                .errorAlert()
        }

        // 应用窗口组
        appWindowGroups()
            .windowStyle(.titleBar)
            .applyRestorationBehaviorDisabled()
            .windowResizability(.contentSize)

        // 右上角的状态栏(可以显示图标的)
        MenuBarExtra(
            content: {
                MenuBarExtraContentView {
                    openSettings()
                }
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
                .environmentObject(AppServices.gameActionManager)
                .environmentObject(AppServices.gameStatusManager)
            },
            label: {
                Image("menu-png").resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
        )
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
        UNUserNotificationCenter.current().delegate = delegate
        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }
    }

    private func cleanupWindowDataOnLaunch() {
        // 应用启动时清理所有窗口数据
        AppServices.windowDataStore.cleanup(for: .aiChat)
        AppServices.windowDataStore.cleanup(for: .skinPreview)
    }
}
