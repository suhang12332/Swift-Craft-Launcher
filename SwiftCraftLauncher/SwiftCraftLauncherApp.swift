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

        // 统一菜单清理：启动后、激活时、稍后重试
        func removeUnwantedMenus() {
            guard let mainMenu = NSApplication.shared.mainMenu else { return }
            // 移除 文件
            if let idx = mainMenu.items.firstIndex(where: { $0.title == "File" || $0.title == "文件" }) {
                mainMenu.removeItem(at: idx)
            }
            // 移除 编辑
            if let idx = mainMenu.items.firstIndex(where: { $0.title == "Edit" || $0.title == "编辑" }) {
                mainMenu.removeItem(at: idx)
            }
            // 移除 显示(View)
            if let idx = mainMenu.items.firstIndex(where: { item in
                ["View", "显示", "视图", "檢視"].contains(item.title)
            }) {
                let item = mainMenu.items[idx]
                mainMenu.removeItem(at: idx)
                item.isHidden = true
            }
            // 移除 窗口(Window)
            if let idx = mainMenu.items.firstIndex(where: { item in
                ["Window", "窗口", "視窗"].contains(item.title)
            }) {
                let item = mainMenu.items[idx]
                mainMenu.removeItem(at: idx)
                item.isHidden = true
            }
            // 重命名 帮助 -> 关于与帮助
            if let helpItem = mainMenu.items.first(where: { $0.title == "Help" || $0.title == "帮助" }) {
                helpItem.title = "关于与帮助"
            }
            // 从应用菜单中移除 Services / Hide Others
            if let appMenuItem = mainMenu.items.first, let appSubmenu = appMenuItem.submenu {
                if let idx = appSubmenu.items.firstIndex(where: { $0.title == "Services" || $0.title == "服务" }) {
                    appSubmenu.removeItem(at: idx)
                }
                if let idx = appSubmenu.items.firstIndex(where: { $0.title == "Hide Others" || $0.title == "隐藏其他" }) {
                    appSubmenu.removeItem(at: idx)
                }
            }
            // 进一步抑制系统自动指向的菜单
            NSApp.windowsMenu = nil
            NSApp.servicesMenu = nil
            if let helpMenu = NSApp.helpMenu { helpMenu.title = "关于与帮助" }
        }

        // 初次清理
        DispatchQueue.main.async { removeUnwantedMenus() }
        // 延时重试，避免系统二次填充
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { removeUnwantedMenus() }
        // 应用激活时再清理一次
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            removeUnwantedMenus()
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
        .commands {
            // 不创建 Window / View 相关菜单项
            CommandGroup(replacing: .windowArrangement) { }
            // 抑制 View 菜单常见群组（侧边栏、工具栏）
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(replacing: .toolbar) { }
            // 抑制 Edit 菜单常见群组（撤销/粘贴板/文本编辑）
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .textEditing) { }
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
        // 右上角的状态栏(可以显示图标的)
        MenuBarExtra(
            content: {
                Button("menu.statusbar.placeholder".localized()) {
                }
            },
            label: {
                Image("menu-png").resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)  // 菜单栏常见大小
                // 推荐保持模板模式
            }
        )
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
