//
//  ModDependencyGraphWindowContent.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import ModDependencyGraphKit
import SwiftUI

/// Payload used by the auxiliary dependency-graph window.
struct ModDependencyGraphWindowPayload {
    let game: GameVersionInfo
}

/// Root content of the auxiliary mod dependency graph window.
struct ModDependencyGraphWindowContent: View {
    @Environment(DIContainer.self)
    private var container

    var body: some View {
        if let payload = container.ui.windowManager.readPayload(
            for: .modDependencyGraph,
            as: ModDependencyGraphWindowPayload.self,
        ) {
            let game = payload.game
            let gameInfo = ModDependencyGraphGame(game: game, icon: nil)

            ModDependencyGraphWindowView(
                gameID: game.id,
                gameName: gameInfo.title,
                gameDetail: gameInfo.detail,
                graphProvider: {
                    try await ModDependencyGraphAppService.buildGraph(for: game)
                },
                gameIconProvider: {
                    await ModDependencyIconLoader.loadGameIcon(for: game)
                },
                onSaveError: { message in
                    AppLog.game.error(message)
                    DIContainer.shared.core.errorHandler.handle(
                        GlobalError.fileSystem(
                            i18nKey: "error.filesystem.image_save_failed",
                            level: .popup,
                            message: message,
                        ),
                    )
                },
            )
        }
    }
}
