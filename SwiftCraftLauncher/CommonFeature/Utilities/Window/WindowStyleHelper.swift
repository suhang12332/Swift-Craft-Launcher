//
//  WindowStyleHelper.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Configures standard window appearance by disabling miniaturize and resize.
enum WindowStyleHelper {
    /// Removes miniaturize, resize, and full-screen capabilities from a window.
    static func configureStandardWindow(_ window: NSWindow) {
        window.styleMask.remove([.miniaturizable, .resizable])
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

/// Applies the standard window style and sets the window identifier and title.
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
                },
            )
    }
}

extension View {
    func windowStyleConfig(for windowID: AuxiliaryWindowID) -> some View {
        modifier(WindowStyleConfig(windowID: windowID))
    }
}

/// Cleans up window data when the view disappears.
struct WindowCleanup: ViewModifier {
    let windowID: AuxiliaryWindowID
    private let windowDataStore: WindowDataStore

    init(windowID: AuxiliaryWindowID, windowDataStore: WindowDataStore) {
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
    func windowCleanup(for windowID: AuxiliaryWindowID, windowDataStore: WindowDataStore) -> some View {
        modifier(WindowCleanup(windowID: windowID, windowDataStore: windowDataStore))
    }
}
