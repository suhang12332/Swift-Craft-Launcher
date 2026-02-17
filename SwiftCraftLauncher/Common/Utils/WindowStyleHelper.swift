//
//  WindowStyleHelper.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import AppKit
import SwiftUI

/// 窗口样式配置工具
enum WindowStyleHelper {
    /// 配置标准窗口样式（禁用缩小和放大）
    static func configureStandardWindow(_ window: NSWindow) {
        window.styleMask.remove([.miniaturizable, .resizable])
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    /// 从工具栏右键菜单中移除「仅文字」选项，只保留「仅图标」与「文字和图标」
    static func disableToolbarTextOnlyMode(_ window: NSWindow) {
        guard let toolbar = window.toolbar else { return }
        // 使用 _toolbarView 访问工具栏视图以获取其上下文菜单（系统未公开允许的 display 模式 API）
        guard let toolbarView = toolbar.value(forKey: "_toolbarView") as? NSView,
              let menu = toolbarView.menu else { return }
        let textOnlyTag = 3 // 系统菜单中「仅文字」对应的 tag
        if let index = menu.items.firstIndex(where: { $0.action == NSSelectorFromString("changeToolbarDisplayMode:") && $0.tag == textOnlyTag }) {
            menu.removeItem(at: index)
        }
    }
}

/// 窗口样式配置修饰符
struct WindowStyleConfig: ViewModifier {
    let windowID: WindowID

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor(synchronous: false) { window in
                    // 确保窗口 identifier 被正确设置（用于单例查找）
                    if window.identifier?.rawValue != windowID.rawValue {
                        window.identifier = NSUserInterfaceItemIdentifier(windowID.rawValue)
                    }

                    // 统一使用标准窗口样式
                    WindowStyleHelper.configureStandardWindow(window)
                }
            )
    }
}

extension View {
    /// 应用窗口样式配置
    func windowStyleConfig(for windowID: WindowID) -> some View {
        modifier(WindowStyleConfig(windowID: windowID))
    }
}

/// 窗口清理修饰符
struct WindowCleanup: ViewModifier {
    let windowID: WindowID

    func body(content: Content) -> some View {
        content
            .onDisappear {
                WindowDataStore.shared.cleanup(for: windowID)
            }
    }
}

extension View {
    /// 应用窗口清理配置
    func windowCleanup(for windowID: WindowID) -> some View {
        modifier(WindowCleanup(windowID: windowID))
    }
}
