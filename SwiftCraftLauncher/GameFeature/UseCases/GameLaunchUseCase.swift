//
//  GameLaunchUseCase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Owns the launch/stop state machine for a Minecraft game session.
///
/// UI surfaces call ``toggleGameState(player:game:)`` and read
/// ``isLaunching(gameId:userId:)``; they never mutate the launching state or
/// present the missing-player error themselves.
@MainActor
@Observable
final class GameLaunchUseCase {
    /// Whether the game is currently launching for the given player.
    func isLaunching(gameId: String, userId: String) -> Bool {
        DIContainer.shared.core.gameStatusManager.isGameLaunching(gameId: gameId, userId: userId)
    }

    /// Launches the game when it is stopped, or stops it when it is running.
    /// Presents an error when no player is available and ignores re-entrant
    /// launches while another launch is in progress.
    func toggleGameState(player: Player?, game: GameVersionInfo) async {
        guard let player else {
            presentMissingPlayerError()
            return
        }

        let userId = player.id
        guard !DIContainer.shared.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: userId) else {
            return
        }

        if DIContainer.shared.core.gameStatusManager.isGameRunning(gameId: game.id, userId: userId) {
            await stopGame(player: player, game: game)
        } else {
            await launchGame(player: player, game: game)
        }
    }

    private func launchGame(player: Player, game: GameVersionInfo) async {
        let userId = player.id
        DIContainer.shared.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
        defer {
            DIContainer.shared.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false)
        }

        let command = MinecraftLaunchCommand(player: player, game: game)
        do {
            try await command.launchGame()
        } catch {
            AppLog.game.error("Failed to launch game: \(error.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
        }
    }

    private func stopGame(player: Player, game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.stopGame()
    }

    private func presentMissingPlayerError() {
        let error = GlobalError
            .player(i18nKey: "sidebar.alert.no_player_for_launch.message", level: .popup)
            .withTitleKey("sidebar.alert.no_player.title")
        DIContainer.shared.core.errorHandler.handle(error)
    }
}
