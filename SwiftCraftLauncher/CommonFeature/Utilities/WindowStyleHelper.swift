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
    let windowID: AuxiliaryWindowID

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor(synchronous: false) { window in
                    if window.identifier?.rawValue != windowID.rawValue {
                        window.identifier = NSUserInterfaceItemIdentifier(windowID.rawValue)
                    }
                    if window.title != windowID.localizedTitle {
                        window.title = windowID.localizedTitle
                    }
                    WindowStyleHelper.configureStandardWindow(window)
                }
            )
    }
}

extension View {
    func windowStyleConfig(for windowID: AuxiliaryWindowID) -> some View {
        modifier(WindowStyleConfig(windowID: windowID))
    }
}

struct WindowCleanup: ViewModifier {
    let windowID: AuxiliaryWindowID
    private let windowDataStore: WindowDataStore

    init(windowID: AuxiliaryWindowID, windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        self.windowID = windowID
        self.windowDataStore = windowDataStore
    }

    func body(content: Content) -> some View {
        content
            .onDisappear {
                windowDataStore.cleanup(for: windowID)
            }
    }
}

extension View {
    func windowCleanup(for windowID: AuxiliaryWindowID) -> some View {
        modifier(WindowCleanup(windowID: windowID))
    }
}
