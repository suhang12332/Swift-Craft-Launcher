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

/// 临时窗口管理器（基于纯 AppKit）
@MainActor
class TemporaryWindowManager: ObservableObject {
    // 窗口存储：UUID -> (NSWindow, NSHostingController)
    private var windows: [UUID: (window: NSWindow, hostingController: NSHostingController<AnyView>)] = [:]
    // 标题到窗口ID的映射（用于防止重复窗口）
    private var titleToWindowID: [String: UUID] = [:]

    static let shared = TemporaryWindowManager()

    private init() {}

    /// 显示临时窗口
    /// - Parameters:
    ///   - content: SwiftUI 视图内容（应该已经配置好所有需要的环境对象）
    ///   - config: 窗口配置
    func showWindow<T: View>(content: T, config: TemporaryWindowConfig) {
        // 如果已经有相同 title 的窗口，先关闭它
        if let existingID = titleToWindowID[config.title] {
            closeWindow(for: existingID)
        }

        let windowID = UUID()

        // 计算窗口大小（优先使用配置的大小）
        let contentSize: NSSize
        if let width = config.width, let height = config.height {
            // 直接使用配置的大小
            contentSize = NSSize(width: width, height: height)
        } else {
            // 如果没有配置大小，创建临时 Hosting Controller 来计算内容大小
            let tempHostingController = NSHostingController(rootView: AnyView(content))
            tempHostingController.view.layoutSubtreeIfNeeded()
            let size = tempHostingController.view.fittingSize
            contentSize = NSSize(
                width: config.width ?? max(size.width, 400),
                height: config.height ?? max(size.height, 300)
            )
        }

        // 创建窗口（使用计算好的大小）
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // 创建 SwiftUI 内容的 Hosting Controller
        let hostingController = NSHostingController(rootView: AnyView(content))

        // 配置窗口
        window.title = config.title
        window.contentViewController = hostingController

        // 确保窗口大小正确（强制使用配置的大小）
        if let width = config.width, let height = config.height {
            window.setContentSize(NSSize(width: width, height: height))
        }

        window.center()

        // 配置窗口样式
        configureWindowStyle(window, with: config)

        // 设置窗口标识符
        window.identifier = NSUserInterfaceItemIdentifier("temporaryWindow_\(windowID.uuidString)")

        // 设置窗口 delegate
        let delegate = WindowDelegate(windowID: windowID, manager: self)
        window.delegate = delegate

        // 存储窗口引用
        windows[windowID] = (window, hostingController)

        if !config.title.isEmpty {
            titleToWindowID[config.title] = windowID
        }

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
    }

    /// 配置窗口样式
    private func configureWindowStyle(_ window: NSWindow, with config: TemporaryWindowConfig) {
        // 检查是否是创建房间或加入房间窗口（禁用所有窗口控制按钮）
        let isEasyTierRoomWindow = config.title == "menubar.room.create".localized() ||
                                   config.title == "menubar.room.join".localized()

        if isEasyTierRoomWindow {
            // 禁用所有窗口控制按钮
            window.styleMask.remove([.closable, .miniaturizable, .resizable])
            window.standardWindowButton(.closeButton)?.isEnabled = false
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        } else {
            // 其他窗口只禁用缩小和放大
            window.styleMask.remove([.miniaturizable, .resizable])
            window.collectionBehavior.insert(.fullScreenNone)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }

    /// 根据 ID 关闭窗口
    func closeWindow(for id: UUID) {
        guard let (window, _) = windows[id] else { return }

        // 清理标题映射
        let title = window.title
        if !title.isEmpty {
            titleToWindowID.removeValue(forKey: title)
        }

        // 关闭窗口（delegate 会自动清理）
        window.close()
    }

    /// 根据标题关闭窗口
    func closeWindow(withTitle title: String) {
        guard let windowID = titleToWindowID[title] else { return }
        closeWindow(for: windowID)
    }

    /// 窗口关闭回调
    func handleWindowDidClose(for id: UUID) {
        windows.removeValue(forKey: id)
    }

    /// 清理所有窗口
    func cleanupAllWindows() {
        // 复制 keys，避免在迭代时修改字典
        let windowIDs = Array(windows.keys)
        for id in windowIDs {
            closeWindow(for: id)
        }

        // 确保所有窗口都已关闭
        windows.removeAll()
        titleToWindowID.removeAll()
    }

    var hasWindow: Bool {
        !windows.isEmpty
    }
}

// MARK: - Window Delegate

/// 窗口代理，用于监听窗口关闭事件
private class WindowDelegate: NSObject, NSWindowDelegate {
    let windowID: UUID
    weak var manager: TemporaryWindowManager?

    init(windowID: UUID, manager: TemporaryWindowManager) {
        self.windowID = windowID
        self.manager = manager
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // 发送窗口关闭通知，包含窗口对象，以便视图可以监听并清理
            if let window = notification.object as? NSWindow {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TemporaryWindowWillClose"),
                    object: window
                )
            }
            manager?.handleWindowDidClose(for: windowID)
            manager = nil
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

    static func easyTierCreateRoom(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 440, height: 200)
    }

    static func easyTierJoinRoom(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 440, height: 200)
    }

    static func peerList(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 1200, height: 500)
    }

    static func easyTierDownload(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 400, height: 100)
    }

    static func skinPreview(title: String) -> TemporaryWindowConfig {
        TemporaryWindowConfig(title: title, width: 1200, height: 800)
    }
}

// MARK: - Window Reference Tracking

/// 窗口状态持有者（用于避免闭包捕获 @State 导致的内存问题）
/// 注意：实现 ObservableObject 是为了满足 @StateObject 的要求，但不会触发视图更新
private class WindowStateHolder: ObservableObject {
    var currentWindow: NSWindow?
}

/// 窗口引用跟踪修饰符
/// 用于自动管理窗口引用，并在窗口关闭时触发清理回调
struct WindowReferenceTracking: ViewModifier {
    /// 窗口关闭时的清理回调
    let onClose: () -> Void
    /// 窗口状态持有者（使用 @StateObject 避免闭包捕获问题）
    @StateObject private var stateHolder = WindowStateHolder()

    func body(content: Content) -> some View {
        let holder = stateHolder
        return content
            .background(
                WindowAccessor(synchronous: false) { [weak holder] window in
                    // 检查状态持有者是否仍然有效
                    guard let holder = holder else { return }

                    // 保存窗口引用 - 使用异步方式避免在视图更新期间修改状态
                    Task { @MainActor [weak holder] in
                        // 再次检查，因为可能在 Task 执行时视图已经销毁
                        guard let holder = holder else { return }
                        holder.currentWindow = window
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                // 检查是否是当前窗口关闭
                if let window = notification.object as? NSWindow, window == stateHolder.currentWindow {
                    onClose()
                }
            }
            .onDisappear {
                // 清理窗口引用
                stateHolder.currentWindow = nil
                // 作为备用清理机制
                onClose()
            }
    }
}

extension View {
    /// 添加窗口引用跟踪功能
    /// - Parameter onClose: 窗口关闭或视图消失时调用的清理回调
    /// - Returns: 添加了窗口引用跟踪的视图
    func windowReferenceTracking(onClose: @escaping () -> Void) -> some View {
        modifier(WindowReferenceTracking(onClose: onClose))
    }
}
