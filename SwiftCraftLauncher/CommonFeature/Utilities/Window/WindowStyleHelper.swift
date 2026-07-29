//
//  WindowStyleHelper.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Configures auxiliary window appearance by disabling miniaturize, resize, and full-screen.
enum WindowStyleHelper {
    static func configureAuxiliaryWindow(_ window: NSWindow) {
        window.styleMask.remove([.miniaturizable, .resizable])
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}
