//
//  WindowAccessor.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import AppKit

/// A SwiftUI wrapper that provides access to the underlying `NSWindow` instance.
struct WindowAccessor: NSViewRepresentable {
    var synchronous: Bool = false
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowAccessorView(callback: callback, synchronous: synchronous)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let accessorView = nsView as? WindowAccessorView, let window = nsView.window {
            accessorView.configureWindow(window)
        }
    }
}

private class WindowAccessorView: NSView {
    var callback: (NSWindow) -> Void
    var synchronous: Bool
    private var hasConfigured = false

    init(callback: @escaping (NSWindow) -> Void, synchronous: Bool) {
        self.callback = callback
        self.synchronous = synchronous
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        self.callback = { _ in }
        self.synchronous = false
        super.init(coder: coder)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let window = window, !hasConfigured {
            hasConfigured = true

            if synchronous {
                configureWindow(window)
            } else {
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
