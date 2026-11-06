//
//  WindowStyleHelper.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Configures auxiliary window appearance.
@MainActor
enum WindowStyleHelper {
    static func configureAuxiliaryWindow(_ window: NSWindow) {
        window.styleMask.remove([.miniaturizable, .resizable])
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    static func allowMaximizeAndMinimize(_ window: NSWindow) {
        window.styleMask.insert([.miniaturizable, .resizable])
        window.collectionBehavior.remove(.fullScreenNone)
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }
}

extension View {
    /// Allows the hosting auxiliary window to be resized, maximized, and minimized.
    func allowsMaximizeAndMinimize() -> some View {
        modifier(WindowMaximizeAndMinimizeAccessor())
    }
}

private struct WindowMaximizeAndMinimizeAccessor: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            WindowAccessor { window in
                WindowStyleHelper.allowMaximizeAndMinimize(window)
            }
        }
    }
}
