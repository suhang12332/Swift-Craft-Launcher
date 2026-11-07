//
//  GameActionsProvider.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Builds `GameActions` for a game using the shared services and current player.
@MainActor
@Observable
final class GameActionsProvider {
    private let container: DIContainer
    private let gameLaunchUseCase: GameLaunchUseCase
    private let playerListViewModel: PlayerListViewModel

    init(
        container: DIContainer,
        gameLaunchUseCase: GameLaunchUseCase,
        playerListViewModel: PlayerListViewModel,
    ) {
        self.container = container
        self.gameLaunchUseCase = gameLaunchUseCase
        self.playerListViewModel = playerListViewModel
    }

    func actions(for game: GameVersionInfo) -> GameActions {
        GameActions(
            game: game,
            container: container,
            gameLaunchUseCase: gameLaunchUseCase,
            player: playerListViewModel.currentPlayer,
        )
    }
}
