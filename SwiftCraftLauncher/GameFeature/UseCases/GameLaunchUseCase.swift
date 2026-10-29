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
/// present launch errors themselves.
@MainActor
@Observable
final class GameLaunchUseCase {
    private let authService = LaunchAuthService()
    private let commandPreparer = LaunchCommandPreparer()
    private let processLauncher = GameProcessLauncher()

    private var statusManager: GameStatusManager {
        DIContainer.shared.core.gameStatusManager
    }

    /// Whether the game is currently launching for the given player.
    func isLaunching(gameId: String, userId: String) -> Bool {
        statusManager.isGameLaunching(gameId: gameId, userId: userId)
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
        guard !statusManager.isGameLaunching(gameId: game.id, userId: userId) else {
            return
        }

        if statusManager.isGameRunning(gameId: game.id, userId: userId) {
            await processLauncher.stop(player: player, game: game)
        } else {
            await launchGame(player: player, game: game)
        }
    }

    private func launchGame(player: Player, game: GameVersionInfo) async {
        let userId = player.id
        statusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
        defer {
            statusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false)
        }

        do {
            if let integrityError = await GameIntegrityChecker.check(game: game) {
                throw integrityError
            }

            let validation = try await authService.validatePlayer(player)
            for error in validation.nonFatalErrors {
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            }

            guard await canLaunchUnderMemoryPressure(for: game) else {
                return
            }

            let credentials = try await authService.makeCredentials(for: validation.player)
            let command = commandPreparer.prepare(
                command: game.launchCommand,
                game: game,
                credentials: credentials,
            )
            try await processLauncher.launch(command: command, player: player, game: game)
        } catch {
            AppLog.game.error("Failed to launch game: \(error.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
        }
    }

    private func canLaunchUnderMemoryPressure(for game: GameVersionInfo) async -> Bool {
        guard DIContainer.shared.ui.gameSettingsManager.enableMemoryPressureWarning else {
            return true
        }

        let level = MemoryPressureChecker.check()
        guard level.isElevated else {
            return true
        }

        AppLog.game.warning("Memory pressure is \(String(describing: level)) before launching \(game.gameName)")
        let choice = await DIContainer.shared.ui.memoryPressureAlertPresenter.requestUserChoice(for: level)
        return choice == .continueAnyway
    }

    private func presentMissingPlayerError() {
        let error = GlobalError
            .player(i18nKey: "sidebar.alert.no_player_for_launch.message", level: .popup)
            .withTitleKey("sidebar.alert.no_player.title")
        DIContainer.shared.core.errorHandler.handle(error)
    }
}
