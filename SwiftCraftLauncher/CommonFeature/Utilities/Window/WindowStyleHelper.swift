//
//  WindowStyleHelper.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

/// Configures auxiliary window appearance.
@MainActor
enum WindowStyleHelper {
    static func configureAuxiliaryWindow(
        _ window: NSWindow,
        for windowID: AuxiliaryWindowID,
    ) {
        let allowsResizing = windowID.allowsMaximizeAndMinimize

        if allowsResizing {
            window.styleMask.insert([.miniaturizable, .resizable])
            window.collectionBehavior.remove(.fullScreenNone)
        } else {
            window.styleMask.remove([.miniaturizable, .resizable])
            window.collectionBehavior.insert(.fullScreenNone)
        }

        window.standardWindowButton(.miniaturizeButton)?.isEnabled = allowsResizing
        window.standardWindowButton(.zoomButton)?.isEnabled = allowsResizing
    }
}
