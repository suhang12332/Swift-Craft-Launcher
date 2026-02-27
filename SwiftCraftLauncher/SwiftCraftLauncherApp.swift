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
    @Environment(\.scenePhase)
    private var scenePhase

    // MARK: - StateObjects
    @StateObject var playerListViewModel = PlayerListViewModel()
    @StateObject var gameRepository = GameRepository()
    @StateObject var gameLaunchUseCase = GameLaunchUseCase()
    @StateObject private var globalErrorHandler = GlobalErrorHandler.shared
    @StateObject private var sparkleUpdateService = SparkleUpdateService.shared
    @StateObject var generalSettingsManager = GeneralSettingsManager.shared
    @StateObject var themeManager = ThemeManager.shared
    @StateObject private var skinSelectionStore = SkinSelectionStore()
    @StateObject private var appIdleManager = AppIdleManager.shared

    // MARK: - Notification Delegate
    private let notificationCenterDelegate = NotificationCenterDelegate()

    init() {
        // 设置通知中心代理，确保前台时也能展示 Banner
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate

        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }
    }

    // MARK: - Body
    var body: some Scene {

        WindowGroup {
            MainView()
                .environment(\.appLogger, Logger.shared)
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
                .environmentObject(sparkleUpdateService)
                .environmentObject(generalSettingsManager)
                .environmentObject(skinSelectionStore)
                .preferredColorScheme(themeManager.currentColorScheme)
                .errorAlert()
                .windowOpener()
                .onAppear {
                    // 应用启动时清理所有窗口数据
                    WindowDataStore.shared.cleanup(for: .aiChat)
                    WindowDataStore.shared.cleanup(for: .skinPreview)
                    appIdleManager.startMonitoring()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    appIdleManager.handleScenePhase(newPhase)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .conditionalRestorationBehavior()
        .commands {

            CommandGroup(after: .appInfo) {
                Button("menu.check.updates".localized()) {
                    sparkleUpdateService.checkForUpdatesWithUI()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
            CommandGroup(after: .help) {
                Button("menu.open.log".localized()) {
                    Logger.shared.openLogFile()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Link("GitHub", destination: URLConfig.API.GitHub.repositoryURL())

                Button("about.contributors".localized()) {
                    WindowManager.shared.openWindow(id: .contributors)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("about.acknowledgements".localized()) {
                    WindowManager.shared.openWindow(id: .acknowledgements)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Link("license.view".localized(), destination: URLConfig.API.GitHub.licenseWebPage())
                    .keyboardShortcut("l", modifiers: [.command, .option])

                Divider()

                Button("ai.assistant.title".localized()) {
                    AIChatManager.shared.openChatWindow()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
//            CommandGroup(replacing: .newItem) { }
//            CommandGroup(replacing: .saveItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(gameRepository)
                .environmentObject(gameLaunchUseCase)
                .environmentObject(playerListViewModel)
                .environmentObject(sparkleUpdateService)
                .environmentObject(generalSettingsManager)
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
                Button("ai.assistant.title".localized()) {
                    AIChatManager.shared.openChatWindow()
                }
            },
            label: {
                Image("menu-png").resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
        )
    }
}
