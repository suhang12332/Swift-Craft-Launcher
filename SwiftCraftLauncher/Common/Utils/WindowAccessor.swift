//
//  WindowAccessor.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/9/19.
//

import SwiftUI
import AppKit

/// SwiftUI 组件，用于访问和操作底层的 macOS NSWindow 对象
struct WindowAccessor: NSViewRepresentable {
    var synchronous: Bool = false
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView(callback: callback, synchronous: synchronous)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 在更新时也尝试获取窗口（如果之前没有获取到）
        if let accessorView = nsView as? WindowAccessorView, let window = nsView.window {
            accessorView.configureWindow(window)
        }
    }
}

/// 自定义 NSView 用于监听窗口变化
private class WindowAccessorView: NSView {
    var callback: (NSWindow) -> Void
    var synchronous: Bool
    private var hasConfigured = false

    init(callback: @escaping (NSWindow) -> Void, synchronous: Bool) {
        self.callback = callback
        self.synchronous = synchronous
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // 当视图添加到窗口时，立即配置窗口
        if let window = window, !hasConfigured {
            hasConfigured = true

            if synchronous {
                // 同步执行，避免延迟导致的闪烁
                configureWindow(window)
            } else {
                // 异步执行
                DispatchQueue.main.async { [weak self] in
                    self?.configureWindow(window)
                }
            }
        }
    }

    func configureWindow(_ window: NSWindow) {
        callback(window)
    }
}
