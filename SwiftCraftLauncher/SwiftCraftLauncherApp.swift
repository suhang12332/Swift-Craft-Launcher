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

@main
struct SwiftCraftLauncherApp: App {
    // MARK: - StateObjects
    @StateObject private var playerListViewModel = PlayerListViewModel()
    @StateObject private var gameRepository = GameRepository()
    @StateObject private var globalErrorHandler = GlobalErrorHandler.shared
    @StateObject private var sparkleUpdateService = SparkleUpdateService.shared
    @StateObject private var generalSettingsManager = GeneralSettingsManager
        .shared
    @StateObject private var skinSelectionStore = SkinSelectionStore()

    // MARK: - Notification Delegate
    private let notificationCenterDelegate = NotificationCenterDelegate()

    @Environment(\.openWindow)
    private var openWindow

    init() {
        // 设置通知中心代理，确保前台时也能展示 Banner
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate

        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }

        // 清理临时窗口管理器，防止应用重启时恢复未关闭的临时窗口
        TemporaryWindowManager.shared.cleanupAllWindows()

        // 提取 gameRepository 到局部变量，避免在 Task 中捕获 self
        let repository = gameRepository
        Task {
            await Self.scanAllGamesModsDirectory(gameRepository: repository)
        }
    }

    // MARK: - Scanning Methods

    /// 扫描所有游戏的 mods 目录
    /// 异步执行，不会阻塞 UI
    private static func scanAllGamesModsDirectory(gameRepository: GameRepository) async {
        let games = gameRepository.games
        Logger.shared.info("开始扫描 \(games.count) 个游戏的 mods 目录")

        // 并发扫描所有游戏
        await withTaskGroup(of: Void.self) { group in
            for game in games {
                group.addTask {
                    await ModScanner.shared.scanGameModsDirectory(game: game)
                }
            }
        }

        Logger.shared.info("完成所有游戏的 mods 目录扫描")
    }

    // MARK: - Body
    var body: some Scene {

        WindowGroup {
            MainView()
                .environmentObject(playerListViewModel)
                .environmentObject(gameRepository)
                .environmentObject(sparkleUpdateService)
                .environmentObject(generalSettingsManager)
                .environmentObject(skinSelectionStore)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .errorAlert()
                .background(TemporaryWindowOpener())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)

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
            }
            CommandGroup(after: .help) {
                Divider()
            }
            CommandGroup(after: .help) {
                Button("about.contributors".localized()) {
                    TemporaryWindowManager.shared.showWindow(
                        content: AboutView(showingAcknowledgements: false)
                            .environmentObject(generalSettingsManager)
                            .preferredColorScheme(generalSettingsManager.currentColorScheme),
                        config: .contributors(title: "about.contributors".localized())
                    )
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(after: .help) {
                Button("about.acknowledgements".localized()) {
                    TemporaryWindowManager.shared.showWindow(
                        content: AboutView(showingAcknowledgements: true)
                            .environmentObject(generalSettingsManager)
                            .preferredColorScheme(generalSettingsManager.currentColorScheme),
                        config: .acknowledgements(title: "about.acknowledgements".localized())
                    )
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
            CommandGroup(after: .help) {
                Button("license.view".localized()) {
                    LicenseManager.shared.showLicense()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
            CommandGroup(after: .help) {
                Divider()
            }
            CommandGroup(after: .help) {
                Button("settings.ai.open_chat".localized()) {
                    AIChatManager.shared.openChatWindow()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
        }

        Settings {
            SettingsView()
                .environmentObject(gameRepository)
                .environmentObject(playerListViewModel)
                .environmentObject(sparkleUpdateService)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .errorAlert()
        }
        .conditionalRestorationBehavior()

        // 临时窗口
        WindowGroup(id: "temporaryWindow", for: TemporaryWindowID.self) { $windowID in
            if let windowID = windowID {
                TemporaryWindowView(windowID: windowID)
                    .environmentObject(generalSettingsManager)
                    .preferredColorScheme(generalSettingsManager.currentColorScheme)
                    .onDisappear {
                        // 窗口关闭时通知管理器
                        TemporaryWindowManager.shared.closeWindow(for: windowID.id)
                    }
            }
        }
        .defaultPosition(.center)

        // 右上角的状态栏(可以显示图标的)
        MenuBarExtra(
            content: {
                Button("settings.ai.open_chat".localized()) {
                    AIChatManager.shared.openChatWindow()
                }

                Divider()

                Button("menu.statusbar.placeholder".localized()) {
                }
            },
            label: {
                Image("menu-png").resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                // 推荐保持模板模式
            }
        )
    }
}
