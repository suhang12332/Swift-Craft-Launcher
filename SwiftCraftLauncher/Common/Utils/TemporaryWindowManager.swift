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
    let showCloseButton: Bool

    init(title: String = "", width: CGFloat? = nil, height: CGFloat? = nil, showCloseButton: Bool = false) {
        self.title = title
        self.width = width
        self.height = height
        self.showCloseButton = showCloseButton
    }
}

/// 临时窗口管理器
@MainActor
class TemporaryWindowManager: ObservableObject {
    private var currentWindow: NSWindow?

    static let shared = TemporaryWindowManager()

    /// 显示临时窗口
    func showWindow<T: View>(
        content: T,
        config: TemporaryWindowConfig
    ) {
        closeWindow()

        let hostingView = NSHostingView(rootView: AnyView(content))
        let fittingSize = hostingView.fittingSize

        // 使用传入的尺寸，未传入的则自适应内容
        let windowSize = CGSize(
            width: config.width ?? max(fittingSize.width, 400),
            height: config.height ?? max(fittingSize.height, 200)
        )

        // 根据配置决定窗口样式
        var styleMask: NSWindow.StyleMask = [.titled]
        if config.showCloseButton {
            styleMask.insert(.closable)
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.title = config.title
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        currentWindow = window
    }

    /// 关闭当前窗口
    func closeWindow() {
        currentWindow?.close()
        currentWindow = nil
    }

    /// 检查窗口是否显示
    var isWindowShowing: Bool {
        currentWindow != nil
    }
}
