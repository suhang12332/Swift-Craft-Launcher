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
