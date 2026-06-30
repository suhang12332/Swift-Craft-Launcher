//
//  GameLaunchUseCase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A use case that manages launching and stopping a Minecraft game session.
final class GameLaunchUseCase: ObservableObject {
    /// Launches a Minecraft game session.
    /// - Parameters:
    ///   - player: The current player, or `nil` to use default authentication parameters.
    ///   - game: The game version to launch.
    func launchGame(player: Player?, game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.launchGame()
    }

    /// Stops a running Minecraft game session.
    /// - Parameters:
    ///   - player: The current player, used to locate the process to stop. Pass `nil` to use an empty user ID.
    ///   - game: The game version to stop.
    func stopGame(player: Player?, game: GameVersionInfo) async {
        let command = MinecraftLaunchCommand(player: player, game: game)
        await command.stopGame()
    }
}
