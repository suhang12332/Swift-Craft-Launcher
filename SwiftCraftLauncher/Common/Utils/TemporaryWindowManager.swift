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
    @Published private(set) var pendingWindowID: UUID?

    // 窗口数据存储
    private var windowDataMap: [UUID: TemporaryWindowData] = [:]
    // 窗口实例存储
    private var windowMap: [UUID: NSWindow] = [:]
    // 标题到窗口ID的映射（用于防止重复窗口）
    private var titleToWindowIDMap: [String: UUID] = [:]
    // 正在清理的窗口ID集合（防止重复清理）
    private var cleaningWindowIDs: Set<UUID> = []
    // 已设置位置的窗口ID集合（避免重复设置位置）
    private var positionedWindowIDs: Set<UUID> = []

    static let shared = TemporaryWindowManager()

    private init() {}

    /// 显示临时窗口
    func showWindow<T: View>(content: T, config: TemporaryWindowConfig) {
        // 如果已经有相同 title 的窗口，先关闭它
        if let existingID = titleToWindowIDMap[config.title] {
            closeWindow(for: existingID)
        }

        let windowData = TemporaryWindowData(content: AnyView(content), config: config)
        windowDataMap[windowData.id] = windowData

        if !config.title.isEmpty {
            titleToWindowIDMap[config.title] = windowData.id
        }

        // 触发窗口打开
        pendingWindowID = windowData.id
    }

    /// 根据 ID 获取窗口数据
    func getWindowData(for id: UUID) -> TemporaryWindowData? {
        windowDataMap[id]
    }

    /// 关闭当前待打开的窗口
    func clearPendingWindow() {
        pendingWindowID = nil
    }

    /// 注册窗口实例
    func registerWindow(_ window: NSWindow, for id: UUID) {
        guard let windowData = windowDataMap[id] else {
            // 如果窗口数据已经不存在，直接关闭窗口
            window.close()
            return
        }

        // 检查这是否是新窗口（不在 windowMap 中）还是已存在的窗口
        let isNewWindow = windowMap[id] == nil

        windowMap[id] = window

        // 设置窗口关闭和显示代理，确保窗口关闭时正确清理，并在显示前配置
        let delegate = WindowDelegate(windowID: id, manager: self, config: windowData.config)
        objc_setAssociatedObject(window, &AssociatedKeys.delegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        window.delegate = delegate

        // 立即配置窗口（如果窗口还未显示，这会在显示前完成配置）
        // 如果窗口已经显示，也需要配置以避免使用默认大小
        configureWindowImmediately(window, with: windowData.config, delegate: delegate, isNewWindow: isNewWindow)
    }

    /// 立即配置窗口（在窗口显示前或刚显示时）
    private func configureWindowImmediately(_ window: NSWindow, with config: TemporaryWindowConfig, delegate: WindowDelegate, isNewWindow: Bool) {
        // 标记为已配置，避免重复配置
        guard !delegate.hasConfigured else { return }
        delegate.hasConfigured = true

        // 检查窗口是否已经设置过位置
        let hasBeenPositioned = positionedWindowIDs.contains(delegate.windowID)

        // 设置窗口标题
        window.title = config.title

        // 设置窗口大小（必须在窗口显示前完成）
        // 只对新窗口且未设置过位置的窗口进行居中
        let shouldCenter = isNewWindow && !window.isVisible && !hasBeenPositioned

        if let width = config.width, let height = config.height {
            window.setContentSize(NSSize(width: width, height: height))
            // 只有在新窗口且还未显示且未设置过位置时才居中
            if shouldCenter {
                window.center()
                positionedWindowIDs.insert(delegate.windowID)
            }
        } else if let width = config.width {
            let currentHeight = window.contentRect(forFrameRect: window.frame).height
            window.setContentSize(NSSize(width: width, height: currentHeight))
            if shouldCenter {
                window.center()
                positionedWindowIDs.insert(delegate.windowID)
            }
        } else if let height = config.height {
            let currentWidth = window.contentRect(forFrameRect: window.frame).width
            window.setContentSize(NSSize(width: currentWidth, height: height))
            if shouldCenter {
                window.center()
                positionedWindowIDs.insert(delegate.windowID)
            }
        }

        // 配置窗口样式
        configureWindowStyle(window, with: config)
    }

    /// 配置窗口样式
    private func configureWindowStyle(_ window: NSWindow, with config: TemporaryWindowConfig) {
        // 检查是否是创建房间或加入房间窗口（禁用所有窗口控制按钮）
        let isEasyTierRoomWindow = config.title == "menubar.room.create".localized() || config.title == "menubar.room.join".localized()

        if isEasyTierRoomWindow {
            // 禁用关闭按钮
            window.standardWindowButton(.closeButton)?.isEnabled = false
            // 移除可关闭能力
            window.styleMask.remove(.closable)
            // 禁用缩小按钮
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            window.styleMask.remove(.miniaturizable)
            // 禁用放大按钮
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.styleMask.remove(.resizable)
        } else {
            // 其他窗口只禁用缩小和放大
            window.styleMask.remove(.miniaturizable)
            window.collectionBehavior.insert(.fullScreenNone)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }

    /// 根据 ID 关闭特定窗口
    func closeWindow(for id: UUID) {
        // 先清理窗口的 delegate 和关联对象，避免内存泄漏
        if let window = windowMap[id] {
            // 清理 delegate 关联对象
            objc_setAssociatedObject(window, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // 清除 delegate 引用
            window.delegate = nil
            // 关闭窗口
            window.close()
        }

        // 清理窗口数据
        cleanupWindowData(for: id)
    }

    /// 根据标题关闭窗口
    func closeWindow(withTitle title: String) {
        guard let windowID = titleToWindowIDMap[title] else { return }
        closeWindow(for: windowID)
    }

    /// 窗口关闭回调（由 WindowDelegate 调用）
    func handleWindowWillClose(for id: UUID) {
        // 清理窗口的 delegate 和关联对象
        if let window = windowMap[id] {
            // 清理 delegate 关联对象
            objc_setAssociatedObject(window, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // 清除 delegate 引用
            window.delegate = nil
        }

        // 清理窗口数据
        cleanupWindowData(for: id)
    }

    /// 清理窗口数据
    private func cleanupWindowData(for id: UUID) {
        // 防止重复清理
        guard !cleaningWindowIDs.contains(id) else { return }
        cleaningWindowIDs.insert(id)
        defer { cleaningWindowIDs.remove(id) }

        // 获取窗口数据（用于清理标题映射）
        let windowData = windowDataMap[id]

        // 清理标题映射
        if let windowData = windowData {
            if !windowData.config.title.isEmpty {
                titleToWindowIDMap.removeValue(forKey: windowData.config.title)
            }
        }

        // 清理所有映射和数据
        windowDataMap.removeValue(forKey: id)
        windowMap.removeValue(forKey: id)
        positionedWindowIDs.remove(id)

        // 如果这是待打开的窗口，清除待打开状态
        if pendingWindowID == id {
            pendingWindowID = nil
        }
    }

    /// 清理所有窗口数据
    func cleanupAllWindows() {
        // 关闭所有已注册的窗口，并清理 delegate
        for (id, window) in windowMap {
            // 清理 delegate 关联对象
            objc_setAssociatedObject(window, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // 清除 delegate 引用
            window.delegate = nil
            // 关闭窗口
            window.close()
            // 清理对应的窗口数据
            cleanupWindowData(for: id)
        }

        // 清理所有数据映射（如果上面的循环已经清理了，这里是双重保险）
        windowMap.removeAll(keepingCapacity: false)
        windowDataMap.removeAll(keepingCapacity: false)
        titleToWindowIDMap.removeAll(keepingCapacity: false)
        cleaningWindowIDs.removeAll(keepingCapacity: false)
        positionedWindowIDs.removeAll(keepingCapacity: false)
        pendingWindowID = nil

        // 从 NSApplication 中查找并关闭所有临时窗口（防止窗口恢复）
        // 通过窗口的 identifier 来识别临时窗口
        let allWindows = NSApplication.shared.windows
        for window in allWindows {
            // 检查是否是临时窗口（通过 identifier 判断）
            // 临时窗口的 identifier 可能包含 "temporaryWindow"
            if let identifier = window.identifier?.rawValue,
               identifier.contains("temporaryWindow") {
                // 清理 delegate
                if window.delegate is WindowDelegate {
                    objc_setAssociatedObject(window, &AssociatedKeys.delegate, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    window.delegate = nil
                }
                window.close()
            }
        }
    }

    var hasWindow: Bool {
        !windowDataMap.isEmpty
    }
}

// MARK: - Window Delegate

/// 关联键，用于将 delegate 关联到 NSWindow
private enum AssociatedKeys {
    static var delegate: UInt8 = 0
}

/// 窗口代理，用于监听窗口关闭和显示事件
private class WindowDelegate: NSObject, NSWindowDelegate {
    let windowID: UUID
    weak var manager: TemporaryWindowManager?
    var config: TemporaryWindowConfig?
    var hasConfigured = false

    init(windowID: UUID, manager: TemporaryWindowManager, config: TemporaryWindowConfig) {
        self.windowID = windowID
        self.manager = manager
        self.config = config
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            manager?.handleWindowWillClose(for: windowID)
            // 清理引用，避免内存泄漏
            manager = nil
            config = nil
        }
    }
}

/// 临时窗口视图包装器
struct TemporaryWindowView: View {
    let windowID: TemporaryWindowID
    @StateObject private var windowManager = TemporaryWindowManager.shared

    var body: some View {
        Group {
            if let windowData = windowManager.getWindowData(for: windowID.id) {
                windowData.content
                    .background(
                        WindowAccessor(synchronous: true) { window in
                            // 注册窗口实例到管理器，立即配置以避免闪烁
                            windowManager.registerWindow(window, for: windowID.id)
                        }
                    )
            } else {
                // 如果窗口数据不存在，显示空视图
                Color.clear
                    .frame(width: 0, height: 0)
                    .onAppear {
                        // 如果窗口数据不存在，关闭窗口
                        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == windowID.id.uuidString }) {
                            window.close()
                        }
                    }
            }
        }
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
            .onChange(of: windowManager.pendingWindowID) { _, newValue in
                if let windowID = newValue {
                    // 打开窗口
                    openWindow(id: "temporaryWindow", value: TemporaryWindowID(id: windowID))
                    // 清除待打开状态（延迟清除，确保 openWindow 已执行）
                    DispatchQueue.main.async {
                        windowManager.clearPendingWindow()
                    }
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

/// 窗口引用跟踪修饰符
/// 用于自动管理窗口引用，并在窗口关闭时触发清理回调
struct WindowReferenceTracking: ViewModifier {
    /// 窗口关闭时的清理回调
    let onClose: () -> Void
    /// 窗口引用（内部状态）
    @State private var currentWindow: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor(synchronous: false) { window in
                    // 保存窗口引用 - 使用异步方式避免在视图更新期间修改状态
                    Task { @MainActor in
                        currentWindow = window
                    }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                // 检查是否是当前窗口关闭
                if let window = notification.object as? NSWindow, window == currentWindow {
                    onClose()
                }
            }
            .onDisappear {
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
