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

        URLCache.shared = URLCache(
            memoryCapacity: 2 * 1024 * 1024,
            diskCapacity: 10 * 1024 * 1024,
            diskPath: nil
        )

        // 设置通知中心代理，确保前台时也能展示 Banner
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate

        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }

        AppServices.freeze()
    }

    // MARK: - Body
    var body: some Scene {

        Window(Bundle.main.appName, id: WindowID.main.rawValue) {
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
                .onOpenURL { url in
                    openURLModPackImportPresenter.handle(url: url)
                }
                .onAppear {
                    // 应用启动时清理所有窗口数据
                    windowDataStore.cleanup(for: .aiChat)
                    windowDataStore.cleanup(for: .skinPreview)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            if sparkleUpdateService.updateAvailable {
                CommandMenu(String(format: "menu.update.released.title".localized(), sparkleUpdateService.versionString)) {
                    Link("menu.view.release.details".localized(), destination: URLConfig.API.GitHub.releaseTag(
                        version: sparkleUpdateService.versionString
                    ))
                }
            }
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
                Link("menu.community.website".localized(), destination: URLConfig.API.Community.website())

                Menu("menu.community".localized()) {
                    Link("menu.community.discussions".localized(), destination: URLConfig.API.Community.discussions())
                    Link("menu.community.discord".localized(), destination: URLConfig.API.Community.discord())
                    Link("menu.community.qq".localized(), destination: URLConfig.API.Community.qq())
                }

                Link("menu.community.report.issue".localized(), destination: URLConfig.API.Community.issues())

                Button("about.contributors".localized()) {
                    windowManager.openWindow(id: .contributors)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("about.acknowledgements".localized()) {
                    windowManager.openWindow(id: .acknowledgements)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Link("license.view".localized(), destination: URLConfig.API.GitHub.license())
                    .keyboardShortcut("l", modifiers: [.command, .option])

                Divider()

                Button("ai.assistant.title".localized()) {
                    aiChatManager.openChatWindow()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
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
}
