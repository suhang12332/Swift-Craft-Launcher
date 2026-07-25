//
//  GameCrashAlertModifier.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Presents an alert when a game crashes, offering to open the log directory.
struct GameCrashAlertModifier: ViewModifier {
    @State private var isPresented = false
    @State private var crashDirectory: URL?

    func body(content: Content) -> some View {
        content
            .alert(
                "error.game_launch.game_crashed".localized(),
                isPresented: $isPresented,
            ) {
                Button("menu.open.log".localized()) {
                    if let directory = crashDirectory {
                        NSWorkspace.shared.open(directory)
                    }
                }
                Button("common.close".localized(), role: .cancel) { }
            } message: {
                Text("error.game_launch.game_crashed.description".localized())
            }
            .onReceive(NotificationCenter.default.publisher(for: .gameCrashed)) { notification in
                crashDirectory = notification.userInfo?["directory"] as? URL
                isPresented = true
            }
    }
}

extension View {
    func gameCrashAlert() -> some View {
        modifier(GameCrashAlertModifier())
    }
}
