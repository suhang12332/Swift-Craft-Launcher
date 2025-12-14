//  MLauncherApp.swift
//  MLauncher
//
//  Created by su on 2025/5/30.
//

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
            CommandGroup(after: .appInfo) {
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
