//
//  TemporaryWindowManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI
import AppKit

/// 临时窗口配置
struct TemporaryWindowConfig {
    let title: String
    let width: CGFloat?
    let height: CGFloat?

    init(title: String = "", width: CGFloat? = nil, height: CGFloat? = nil) {
        self.title = title
        self.width = width
        self.height = height
    }
}

/// 临时窗口数据
struct TemporaryWindowData: Identifiable {
    let id: UUID
    let content: AnyView
    let config: TemporaryWindowConfig

    init(id: UUID = UUID(), content: AnyView, config: TemporaryWindowConfig) {
        self.id = id
        self.content = content
        self.config = config
    }
}

/// 临时窗口标识符（用于 WindowGroup）
struct TemporaryWindowID: Identifiable, Hashable, Codable {
    let id: UUID
}

/// 临时窗口管理器（基于 SwiftUI）
@MainActor
class TemporaryWindowManager: ObservableObject {
    @Published var currentWindowData: TemporaryWindowData?
    @Published var shouldOpenWindow: Bool = false
    private var windowIDMap: [UUID: TemporaryWindowData] = [:]

    static let shared = TemporaryWindowManager()

    private init() {}

    /// 显示临时窗口
    func showWindow<T: View>(content: T, config: TemporaryWindowConfig) {
        let windowData = TemporaryWindowData(content: AnyView(content), config: config)
        windowIDMap[windowData.id] = windowData
        currentWindowData = windowData
        shouldOpenWindow = true
    }

    /// 根据 ID 获取窗口数据
    func getWindowData(for id: UUID) -> TemporaryWindowData? {
        windowIDMap[id]
    }

    /// 关闭当前窗口
    func closeWindow() {
        if let id = currentWindowData?.id {
            closeWindow(for: id)
        }
    }

    /// 根据 ID 关闭特定窗口
    func closeWindow(for id: UUID) {
        windowIDMap.removeValue(forKey: id)
        if currentWindowData?.id == id {
            currentWindowData = nil
            shouldOpenWindow = false
        }
    }

    /// 清理所有窗口数据
    func cleanupAllWindows() {
        windowIDMap.removeAll(keepingCapacity: false)
        currentWindowData = nil
        shouldOpenWindow = false
    }

    var isWindowShowing: Bool {
        currentWindowData != nil
    }
}

/// 临时窗口视图包装器
struct TemporaryWindowView: View {
    let windowID: TemporaryWindowID
    @StateObject private var windowManager = TemporaryWindowManager.shared
    @State private var hasConfiguredWindow = false

    var body: some View {
        if let windowData = windowManager.getWindowData(for: windowID.id) {
            windowData.content
                .background(
                    WindowAccessor { window in
                        guard !hasConfiguredWindow else { return }
                        DispatchQueue.main.async {
                            configureWindow(window, with: windowData.config)
                            hasConfiguredWindow = true
                        }
                    }
                )
                .onDisappear {
                    windowManager.closeWindow(for: windowID.id)
                }
        }
    }

    private func configureWindow(_ window: NSWindow, with config: TemporaryWindowConfig) {
        window.title = config.title

        if let width = config.width, let height = config.height {
            window.setContentSize(NSSize(width: width, height: height))
        } else if let width = config.width {
            let currentSize = window.contentView?.frame.size ?? window.contentRect(forFrameRect: window.frame).size
            window.setContentSize(NSSize(width: width, height: currentSize.height))
        } else if let height = config.height {
            let currentSize = window.contentView?.frame.size ?? window.contentRect(forFrameRect: window.frame).size
            window.setContentSize(NSSize(width: currentSize.width, height: height))
        }

        window.styleMask.remove(.miniaturizable)
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

/// 窗口打开辅助视图
struct TemporaryWindowOpener: View {
    @StateObject private var windowManager = TemporaryWindowManager.shared
    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: windowManager.shouldOpenWindow) {
                if windowManager.shouldOpenWindow, let windowData = windowManager.currentWindowData {
                    openWindow(id: "temporaryWindow", value: TemporaryWindowID(id: windowData.id))
                    windowManager.shouldOpenWindow = false
                }
            }
    }
}

// MARK: - TemporaryWindowConfig Presets

extension TemporaryWindowConfig {
    static func contributors(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 280, height: 600)
    }

    static func acknowledgements(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 280, height: 600)
    }

    static func aiChat(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 500, height: 600)
    }

    static func license(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 570, height: 600)
    }

    static func javaDownload(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 400, height: 100)
    }
}
