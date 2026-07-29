//
//  WindowManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

@MainActor
class WindowManager {
    private var openWindowAction: ((AuxiliaryWindowID) -> Void)?
    private var dismissActions: [AuxiliaryWindowID: () -> Void] = [:]
    private var pendingPayloads: [AuxiliaryWindowID: Any] = [:]

    init() { }

    /// Stores a payload that the window of the given type can read.
    func preparePayload<Payload>(_ payload: Payload, for id: AuxiliaryWindowID) {
        pendingPayloads[id] = payload
    }

    /// Returns the payload for the given window type without removing it.
    func readPayload<Payload>(for id: AuxiliaryWindowID, as type: Payload.Type) -> Payload? {
        pendingPayloads[id] as? Payload
    }

    /// Discards any stored payload for the given window type.
    func clearPayload(for id: AuxiliaryWindowID) {
        pendingPayloads.removeValue(forKey: id)
    }

    func setOpenWindowAction(_ action: @escaping (AuxiliaryWindowID) -> Void) {
        openWindowAction = action
    }

    func registerDismissAction(_ action: @escaping () -> Void, for id: AuxiliaryWindowID) {
        dismissActions[id] = action
    }

    func unregisterDismissAction(for id: AuxiliaryWindowID) {
        dismissActions.removeValue(forKey: id)
    }

    /// Opens the specified auxiliary window via SwiftUI's openWindow environment action.
    /// SwiftUI automatically brings an already-open window to the front.
    func openWindow(id: AuxiliaryWindowID) {
        openWindowAction?(id)
    }

    /// Opens the specified auxiliary window and activates the application.
    func showAndActivateWindow(id: AuxiliaryWindowID) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// Closes the specified auxiliary window by invoking its registered dismiss action.
    func closeWindow(id: AuxiliaryWindowID) {
        dismissActions[id]?()
    }

    /// Activates the application and brings the main window to front.
    func showAndActivateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = findMainWindow() {
            bringWindowToFront(window)
            return
        }
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func findMainWindow() -> NSWindow? {
        NSApplication.shared.windows.first { $0.identifier?.rawValue == AppWindowID.main.rawValue }
    }

    private func bringWindowToFront(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
            DispatchQueue.main.async {
                NSApplication.shared.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
            return
        }
        window.makeKeyAndOrderFront(nil)
    }
}

/// Bridges SwiftUI's `openWindow` environment action to `WindowManager`,
/// allowing non-view code to open auxiliary windows.
struct WindowActionBridge: ViewModifier {
    @Environment(\.openWindow)
    private var openWindow

    private let windowManager: WindowManager

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func body(content: Content) -> some View {
        content.onAppear {
            windowManager.setOpenWindowAction { windowID in
                openWindow(value: windowID)
            }
        }
    }
}

extension View {
    func windowOpener(_ windowManager: WindowManager) -> some View {
        modifier(WindowActionBridge(windowManager: windowManager))
    }
}
