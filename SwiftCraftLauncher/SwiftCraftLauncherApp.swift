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
        
        // 移除文件菜单
        DispatchQueue.main.async {
            if let mainMenu = NSApplication.shared.mainMenu {
                // 查找文件菜单
                if let fileMenuIndex = mainMenu.items.firstIndex(where: { $0.title == "File" || $0.title == "文件" }) {
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
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
                .errorAlert()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        WindowGroup("About", id: "aboutWindow") {
            AboutView()
                .environmentObject(generalSettingsManager)
                .preferredColorScheme(generalSettingsManager.currentColorScheme)
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
            CommandGroup(after: .help) {
                Button("menu.open.log".localized()) {
                    openLogFile()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
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
    
    // MARK: - Helper Methods
    private func openLogFile() {
        // 生成当前日期的日志文件名
        let appName = Bundle.main.appName.replacingOccurrences(of: " ", with: "-").lowercased()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let logFileName = "\(appName)-\(dateString).log"
        
        // 获取日志文件路径
        let logPath = AppPaths.logsDirectory!.appendingPathComponent(logFileName)
        
        // 检查文件是否存在
        if FileManager.default.fileExists(atPath: logPath.path) {
            // 使用系统默认应用打开日志文件
            NSWorkspace.shared.open(logPath)
        } else {
            // 如果日志文件不存在，创建并打开
            do {
                try FileManager.default.createDirectory(at: AppPaths.logsDirectory!, withIntermediateDirectories: true)
                try "日志文件已创建 - \(dateString)".write(to: logPath, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(logPath)
            } catch {
                Logger.shared.error("无法创建或打开日志文件: \(error)")
            }
        }
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
