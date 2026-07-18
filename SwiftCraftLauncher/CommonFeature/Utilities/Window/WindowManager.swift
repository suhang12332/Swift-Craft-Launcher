//
//  WindowManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

// Manages application window lifecycle, activation, and front-to-back ordering.
import SwiftUI

@MainActor
class WindowManager {
    private var openAuxiliaryWindowAction: ((AuxiliaryWindowID) -> Void)?

    init() { }

    func setOpenAuxiliaryWindowAction(_ action: @escaping (AuxiliaryWindowID) -> Void) {
        openAuxiliaryWindowAction = action
    }

    private func findWindow(id: AuxiliaryWindowID) -> NSWindow? {
        findWindow(identifier: id.rawValue)
    }

    private func findWindow(identifier: String) -> NSWindow? {
        NSApplication.shared.windows.first { $0.identifier?.rawValue == identifier }
    }

    /// Opens the specified auxiliary window, or brings it to front if already open.
    func openWindow(id: AuxiliaryWindowID) {
        if let existingWindow = findWindow(id: id) {
            bringWindowToFront(existingWindow)
            return
        }

        if let openWindow = openAuxiliaryWindowAction {
            openWindow(id)
        } else {
            NotificationCenter.default.post(
                name: .openWindow,
                object: nil,
                userInfo: ["windowID": id.rawValue],
            )
        }
    }

    /// Opens the specified auxiliary window and activates the application.
    func showAndActivateWindow(id: AuxiliaryWindowID) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = findWindow(id: id) else { return }
            bringWindowToFront(window)
        }
    }

    /// Activates the application and brings the main window to front.
    func showAndActivateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = findWindow(identifier: AppWindowID.main.rawValue) {
            bringWindowToFront(window)
            return
        }
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
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

    /// Closes the specified auxiliary window.
    func closeWindow(id: AuxiliaryWindowID) {
        if let window = findWindow(id: id) {
            window.close()
        }
    }
}

struct WindowOpener: ViewModifier {
    @Environment(\.openWindow)
    private var openWindow
    private let windowManager: WindowManager

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                windowManager.setOpenAuxiliaryWindowAction { windowID in
                    openWindow(value: windowID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openWindow)) { notification in
                if let windowIDString = notification.userInfo?["windowID"] as? String,
                   let windowID = AuxiliaryWindowID(rawValue: windowIDString) {
                    openWindow(value: windowID)
                }
            }
    }
}

extension View {
    func windowOpener(
        _ windowManager: WindowManager,
    ) -> some View {
        modifier(
            WindowOpener(windowManager: windowManager),
        )
    }
}
