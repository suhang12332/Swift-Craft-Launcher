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
