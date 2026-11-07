//
//  TouchBarSupportConfiguration+App.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI
import TouchBarSupport

extension TouchBarSupportConfiguration {
    /// Builds the Touch Bar configuration from the launcher's live services.
    @MainActor
    static func make(
        container: DIContainer,
        gameRepository: GameRepository,
        playerListViewModel: PlayerListViewModel,
        gameActionsProvider: GameActionsProvider,
        openSettings: @escaping @MainActor () -> Void,
    ) -> TouchBarSupportConfiguration {
        @MainActor
        func selectedGame() -> GameVersionInfo? {
            guard let gameId = container.core.selectedGameManager.selectedGameId else { return nil }
            return gameRepository.getGame(by: gameId)
        }

        @MainActor
        func selectedActions() -> GameActions? {
            selectedGame().map(gameActionsProvider.actions(for:))
        }

        return TouchBarSupportConfiguration(
            currentPlayerName: {
                playerListViewModel.currentPlayer?.name
            },
            playerAvatarView: {
                playerListViewModel.currentPlayer.map {
                    AnyView(MinecraftSkinUtils(type: $0.isRemote ? .url : .asset, src: $0.avatarName, size: 28))
                }
            },
            currentGameName: {
                selectedGame()?.gameName
            },
            gameIconImage: {
                selectedGame().flatMap { game in
                    NSImage(contentsOf: AppPaths.profileDirectory(gameName: game.gameName)
                        .appendingPathComponent(game.gameIcon))
                }
            },
            isRunning: {
                selectedActions()?.isRunning ?? false
            },
            isLaunching: {
                selectedActions()?.isLaunching ?? false
            },
            canExportModPack: {
                selectedActions()?.isModded ?? false
            },
            onPlayStop: {
                selectedActions()?.toggleGameState()
            },
            onOpenSettings: {
                selectedActions()?.openAdvancedSettings(openSettings: openSettings)
            },
            onExportModPack: {
                selectedActions()?.presentModPackExport()
            },
            onShowInFinder: {
                selectedActions()?.showInFinder()
            },
            onDeleteInstance: {
                selectedActions()?.requestDeletion()
            },
        )
    }
}
