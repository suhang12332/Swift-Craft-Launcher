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
        gameLaunchUseCase: GameLaunchUseCase,
        playerListViewModel: PlayerListViewModel,
        openSettings: @escaping @MainActor () -> Void,
    ) -> TouchBarSupportConfiguration {
        @MainActor
        func selectedGame() -> GameVersionInfo? {
            guard let gameId = container.core.selectedGameManager.selectedGameId else { return nil }
            return gameRepository.getGame(by: gameId)
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
                guard let gameId = selectedGame()?.id else { return false }
                let userId = playerListViewModel.currentPlayer?.id ?? ""
                return container.core.gameStatusManager.cachedIsGameRunning(gameId: gameId, userId: userId)
            },
            isLaunching: {
                guard let gameId = selectedGame()?.id else { return false }
                let userId = playerListViewModel.currentPlayer?.id ?? ""
                return container.core.gameStatusManager.isGameLaunching(gameId: gameId, userId: userId)
            },
            canExportModPack: {
                selectedGame()?.modLoader != GameLoader.vanilla.displayName
            },
            onPlayStop: {
                guard let player = playerListViewModel.currentPlayer,
                      let game = selectedGame() else {
                    return
                }

                let userId = player.id
                if container.core.gameStatusManager.isGameRunning(gameId: game.id, userId: userId) {
                    Task { @MainActor in
                        await gameLaunchUseCase.stopGame(player: player, game: game)
                    }
                } else {
                    container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                    Task { @MainActor in
                        defer {
                            container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false)
                        }
                        await gameLaunchUseCase.launchGame(player: player, game: game)
                    }
                }
            },
            onOpenSettings: {
                if let selectedId = container.core.selectedGameManager.selectedGameId {
                    container.core.selectedGameManager.setSelectedGameAndOpenAdvancedSettings(selectedId)
                }
                openSettings()
            },
            onExportModPack: {
                guard let game = selectedGame() else { return }
                container.ui.gameDialogsPresenter.presentModPackExport(for: game)
            },
            onShowInFinder: {
                guard let game = selectedGame() else { return }
                container.core.gameActionManager.showInFinder(game: game)
            },
            onDeleteInstance: {
                guard let game = selectedGame() else { return }
                container.ui.gameDialogsPresenter.requestGameDeletion(of: game)
            },
        )
    }
}
