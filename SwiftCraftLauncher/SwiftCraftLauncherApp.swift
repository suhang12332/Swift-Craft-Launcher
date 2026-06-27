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
        Window(Bundle.main.appName, id: AppWindowID.main.rawValue) {
            MainView()
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
                .environmentObject(AppServices.gameActionManager)
                .environmentObject(AppServices.gameStatusManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .errorAlert()
                .windowOpener()
                .onOpenURL { url in
                    AppServices.openURLModPackImportPresenter.handle(url: url)
                }
                .task {
                    AppServices.sparkleUpdateService.scheduleStartupCheckIfNeeded()
                    AppServices.minecraftFriendsPresencePollingCoordinator.start(
                        playerListViewModel: playerListViewModel
                    )
                }
                .onAppear(perform: cleanupWindowDataOnLaunch)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    ProgressDownloadManager.cleanup()
                }
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
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .errorAlert()
        }

        auxiliaryWindowGroup()
            .windowStyle(.titleBar)
            .applyRestorationBehaviorDisabled()
            .windowResizability(.contentSize)

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
                HStack {
                    Image("menu-png")
                        .renderingMode(.template)
                        .scaledToFit()
                    if !gameRepository.games.isEmpty {
                        Text(" \(gameRepository.games.count)")
                    }
                }
            }
        )
    }

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
        AppServices.windowDataStore.cleanup(for: .aiChat)
        AppServices.windowDataStore.cleanup(for: .skinPreview)
    }
}
