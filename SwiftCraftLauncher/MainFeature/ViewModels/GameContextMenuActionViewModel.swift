//
//  GameContextMenuActionViewModel.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Handles context menu actions for launching or stopping a game.
@MainActor
@Observable
final class GameContextMenuActionViewModel {
    init() { }

    /// Toggles the running state of a game by launching or stopping it.
    ///
    /// - Parameters:
    ///   - isRunning: Whether the game is currently running.
    ///   - player: The player associated with the game session, or `nil` for offline play.
    ///   - game: The game version to launch or stop.
    ///   - gameLaunchUseCase: Use case responsible for game launch and termination.
    func toggleGameState(
        isRunning: Bool,
        player: Player?,
        game: GameVersionInfo,
        gameLaunchUseCase: GameLaunchUseCase,
    ) {
        Task {
            if isRunning {
                guard let player else { return }
                await gameLaunchUseCase.stopGame(player: player, game: game)
            } else {
                guard let player else { return }
                let userId = player.id
                DIContainer.shared.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                defer { DIContainer.shared.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                await gameLaunchUseCase.launchGame(player: player, game: game)
            }
        }
    }
}
