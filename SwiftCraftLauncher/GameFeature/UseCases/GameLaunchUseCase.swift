//
//  GameLaunchUseCase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// A use case that manages launching and stopping a Minecraft game session.
@Observable
final class GameLaunchUseCase: @unchecked Sendable {
    /// Launches a Minecraft game session.
    /// - Parameters:
    ///   - player: The current player.
    ///   - game: The game version to launch.
    func launchGame(player: Player, game: GameVersionInfo) async {
        let canLaunch = await MainActor.run {
            let status = DIContainer.shared.core.gameStatusManager
            guard !status.isModPackUpdating(gameId: game.id) else { return false }
            status.setGameLaunching(gameId: game.id, userId: player.id, isLaunching: true)
            return true
        }
        guard canLaunch else { return }
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.launchGame()
        await MainActor.run {
            DIContainer.shared.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: player.id, isLaunching: false)
        }
    }

    /// Stops a running Minecraft game session.
    /// - Parameters:
    ///   - player: The current player, used to locate the process to stop.
    ///   - game: The game version to stop.
    func stopGame(player: Player, game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.stopGame()
    }
}
