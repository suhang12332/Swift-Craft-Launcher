//
//  GameProcessLauncher.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AVFoundation
import Foundation

/// Starts and stops Minecraft game processes.
struct GameProcessLauncher {
    func launch(command: [String], player: Player, game: GameVersionInfo) async throws {
        if game.modLoader != GameLoader.vanilla.displayName,
           AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }

        let javaExecutable = game.javaPath
        guard !javaExecutable.isEmpty else {
            throw GlobalError.configuration(
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup,
                message: "Java path is empty for game=\(game.gameName), javaPath=\(javaExecutable)",
            )
        }

        let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName)
        AppLog.game.info("Game working directory: \(gameWorkingDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaExecutable)
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory

        if !game.environmentVariables.isEmpty {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in EnvironmentVariablesParser.parse(game.environmentVariables) {
                environment[key] = value
            }
            process.environment = environment
        }

        await DIContainer.shared.core.gameSessionStore.storeProcess(
            gameId: game.id,
            userId: player.id,
            process: process,
        )

        do {
            try process.run()

            await MainActor.run {
                DIContainer.shared.core.gameSessionStore.setGameRunning(
                    gameId: game.id,
                    userId: player.id,
                    isRunning: true,
                )
            }
        } catch {
            AppLog.game.error("Failed to launch process: \(error.localizedDescription)")

            await DIContainer.shared.core.gameSessionStore.stopProcess(
                for: game.id,
                userId: player.id,
            )
            await MainActor.run {
                DIContainer.shared.core.gameSessionStore.setGameRunning(
                    gameId: game.id,
                    userId: player.id,
                    isRunning: false,
                )
            }

            throw GlobalError.gameLaunch(
                i18nKey: "error.game_launch.process_failed",
                level: .popup,
                message: "Failed to start process for game=\(game.gameName), javaPath=\(javaExecutable): \(error.localizedDescription)",
            )
        }
    }

    func stop(player: Player, game: GameVersionInfo) async {
        await DIContainer.shared.core.gameSessionStore.stopProcess(
            for: game.id,
            userId: player.id,
        )
    }
}
