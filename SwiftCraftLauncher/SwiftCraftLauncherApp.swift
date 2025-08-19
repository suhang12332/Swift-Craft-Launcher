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
    @StateObject private var generalSettingsManager = GeneralSettingsManager.shared
    @Environment(\.openWindow) private var openWindow

    // 关于页面状态
    @State private var showAboutWindow = false

    init() {
        Task {
            await NotificationManager.requestAuthorizationIfNeeded()
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
                .preferredColorScheme(generalSettingsManager.themeMode.effectiveColorScheme)
                .errorAlert()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        WindowGroup("About", id: "aboutWindow") {
            AboutView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.themeMode.effectiveColorScheme)
                .background(WindowAccessor { window in
                    // 移除关闭、最小化、最大化按钮
                    window.styleMask.remove([.miniaturizable, .resizable])
                    // 禁用全屏
                    window.collectionBehavior.remove(.fullScreenPrimary)
                })
        }
        .windowResizability(.contentSize)
//        .windowStyle(.hiddenTitleBar)
        .windowStyle(.titleBar).windowToolbarStyle(.unified(showsTitle: false))
        
        
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(String(format: "menu.about".localized(), Bundle.main.appName)) {
                    openWindow(id: "aboutWindow")
                    
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button("menu.check.updates".localized()) {
                    sparkleUpdateService.checkForUpdatesWithUI()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(gameRepository)
                .environmentObject(playerListViewModel)
                .environmentObject(sparkleUpdateService)
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.themeMode.effectiveColorScheme)
                .errorAlert()
        }
        // 右上角的状态栏(可以显示图标的)
        MenuBarExtra(content: {
            Button("menu.statusbar.placeholder".localized()) {

            }
        }, label: {
            Image("menu-png").resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 18, height: 18) // 菜单栏常见大小
                     // 推荐保持模板模式
        })
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
