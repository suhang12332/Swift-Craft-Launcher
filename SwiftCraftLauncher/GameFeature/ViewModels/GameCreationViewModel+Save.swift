//
//  GameCreationViewModel+Save.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Extension providing game save logic for `GameCreationViewModel`.
extension GameCreationViewModel {
    func saveGame() async {
        guard let gameRepository,
              let playerListViewModel else {
            AppLog.game.error("GameRepository 或 PlayerListViewModel 未设置")
            return
        }

        let loaderVersion = selectedModLoader == GameLoader.vanilla.displayName ? selectedModLoader : selectedLoaderVersion

        var finalGameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalGameName.isEmpty {
            finalGameName = GameNameGenerator.generateGameName(
                gameVersion: selectedGameVersion,
                loaderVersion: loaderVersion,
                modLoader: selectedModLoader,
            )
            gameNameValidator.gameName = finalGameName
        }

        await gameSetupService.saveGame(
            input: .init(
                gameName: finalGameName,
                selectedGameVersion: selectedGameVersion,
                selectedModLoader: selectedModLoader,
                specifiedLoaderVersion: loaderVersion,
                pendingIconData: pendingIconData,
            ),
            playerListViewModel: playerListViewModel,
            gameRepository: gameRepository,
            onSuccess: {
                Task { @MainActor in
                    self.configuration.actions.onCancel()
                }
            },
            onError: { error, message in
                Task { @MainActor in
                    self.handleNonCriticalError(error, message: message)
                }
            },
        )
    }
}
