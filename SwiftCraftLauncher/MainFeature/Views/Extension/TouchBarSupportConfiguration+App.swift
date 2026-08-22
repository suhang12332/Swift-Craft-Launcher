//
//  TouchBarSupportConfiguration+App.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

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
        TouchBarSupportConfiguration(
            currentPlayerName: {
                TouchBarPlayerAvatarProvider.shared.sync(player: playerListViewModel.currentPlayer)
                return playerListViewModel.currentPlayer?.name
            },
            playerAvatarImage: {
                TouchBarPlayerAvatarProvider.shared.image
            },
            instances: {
                gameRepository.games.map { TouchBarInstance(id: $0.id, name: $0.gameName) }
            },
            currentInstanceID: {
                container.core.selectedGameManager.selectedGameId
            },
            isRunning: { gameId in
                let userId = playerListViewModel.currentPlayer?.id ?? ""
                return container.core.gameStatusManager.cachedIsGameRunning(gameId: gameId, userId: userId)
            },
            isLaunching: { gameId in
                let userId = playerListViewModel.currentPlayer?.id ?? ""
                return container.core.gameStatusManager.isGameLaunching(gameId: gameId, userId: userId)
            },
            onSelectInstance: { gameId in
                container.core.selectedGameManager.setSelectedGame(gameId)
            },
            onPlayStop: {
                guard let player = playerListViewModel.currentPlayer,
                      let selectedId = container.core.selectedGameManager.selectedGameId,
                      let game = gameRepository.games.first(where: { $0.id == selectedId }) else {
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
                guard let selectedId = container.core.selectedGameManager.selectedGameId,
                      let game = gameRepository.games.first(where: { $0.id == selectedId }) else {
                    return
                }
                container.ui.gameDialogsPresenter.presentModPackExport(for: game)
            },
            onShowInFinder: {
                guard let selectedId = container.core.selectedGameManager.selectedGameId,
                      let game = gameRepository.games.first(where: { $0.id == selectedId }) else {
                    return
                }
                container.core.gameActionManager.showInFinder(game: game)
            },
            onDeleteInstance: {
                guard let selectedId = container.core.selectedGameManager.selectedGameId,
                      let game = gameRepository.games.first(where: { $0.id == selectedId }) else {
                    return
                }
                container.ui.gameDialogsPresenter.requestGameDeletion(of: game)
            },
            strings: TouchBarStrings(
                selectGame: "global_resource.select_game".localized(),
                instanceSettings: "touchbar.instance_settings".localized(),
                play: "play.fill".localized(),
                stop: "common.stop".localized(),
                exportModPack: "modpack.export.button".localized(),
                showInFinder: "sidebar.context_menu.show_in_finder".localized(),
            ),
        )
    }
}
