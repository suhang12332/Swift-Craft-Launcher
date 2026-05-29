//
//  WindowManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import SwiftUI
import AppKit

@MainActor
class WindowManager {
    static let shared = WindowManager()

    private var openAuxiliaryWindowAction: ((AuxiliaryWindowID) -> Void)?

    private init() {}

    func setOpenAuxiliaryWindowAction(_ action: @escaping (AuxiliaryWindowID) -> Void) {
        self.openAuxiliaryWindowAction = action
    }

    private func findWindow(id: AuxiliaryWindowID) -> NSWindow? {
        findWindow(identifier: id.rawValue)
    }

    private func findWindow(identifier: String) -> NSWindow? {
        NSApplication.shared.windows.first { $0.identifier?.rawValue == identifier }
    }

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
                userInfo: ["windowID": id.rawValue]
            )
        }
    }

    func showAndActivateWindow(id: AuxiliaryWindowID) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.findWindow(id: id) else { return }
            self.bringWindowToFront(window)
        }
    }

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

    init(windowManager: WindowManager = AppServices.windowManager) {
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
    func windowOpener() -> some View {
        modifier(WindowOpener())
    }
}
