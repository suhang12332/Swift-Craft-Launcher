//
//  GameCrashAlertModifier.swift
//  MainFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Presents an alert when a game crashes, offering to open the log directory.
struct GameCrashAlertModifier: ViewModifier {
    @Environment(DIContainer.self)
    private var container

    func body(content: Content) -> some View {
        let pendingCrashDirectory = container.core.gameSessionStore.pendingCrashDirectory

        return content
            .alert(
                "error.game_launch.game_crashed".localized(),
                isPresented: Binding(
                    get: { pendingCrashDirectory != nil },
                    set: { isPresented in
                        if !isPresented {
                            container.core.gameSessionStore.pendingCrashDirectory = nil
                        }
                    },
                ),
            ) {
                Button("menu.open.log".localized()) {
                    if let pendingCrashDirectory {
                        NSWorkspace.shared.open(pendingCrashDirectory)
                    }
                }
                Button("common.close".localized(), role: .cancel) { }
            } message: {
                Text("error.game_launch.game_crashed.description".localized())
            }
    }
}

extension View {
    func gameCrashAlert() -> some View {
        modifier(GameCrashAlertModifier())
    }
}
