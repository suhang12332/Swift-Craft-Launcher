5//  SwiftCraftLauncherApp.swift
//  Swift Craft Launcher
//
//  Created by su on 2025/5/30.
//
//  Swift Craft Launcher - A modern macOS Minecraft launcher
//
//  Copyright (C) 2025 Swift Craft Launcher Contributors
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
    @Environment(\.openWindow)
    private var openWindow

    init() {
        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
        }

        // 移除文件菜单
        DispatchQueue.main.async {
            if let mainMenu = NSApplication.shared.mainMenu {
                // 查找文件菜单
                if let fileMenuIndex = mainMenu.items.firstIndex(where: {
                    $0.title == "File" || $0.title == "文件"
                }) {
                    mainMenu.removeItem(at: fileMenuIndex)
                }
            }
        }
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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)

        // 关于窗口（共享的 WindowGroup，通过 value 区分）
        WindowGroup("", id: "aboutWindow", for: Bool.self) { $showingAcknowledgements in
            AboutView(showingAcknowledgements: showingAcknowledgements ?? false)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .background(
                    WindowAccessor { window in
                        // 移除关闭、最小化、最大化按钮
                        window.styleMask.remove([.miniaturizable, .resizable])
                        // 禁用全屏
                        window.collectionBehavior.remove(.fullScreenPrimary)
                    }
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .windowResizability(.contentSize)
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
            }
            CommandGroup(after: .help) {
                Divider()
            }
            CommandGroup(after: .help) {
                Button("about.contributors".localized()) {
                    openWindow(id: "aboutWindow", value: false)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(after: .help) {
                Button("about.acknowledgements".localized()) {
                    openWindow(id: "aboutWindow", value: true)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
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
