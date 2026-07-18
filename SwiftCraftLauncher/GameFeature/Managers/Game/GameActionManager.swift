//
//  GameActionManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Provides game-related actions such as revealing in Finder and deletion.
class GameActionManager: ObservableObject {
    init() { }

    /// Reveals the game directory in Finder.
    /// - Parameter game: The game version to locate.
    func showInFinder(game: GameVersionInfo) {
        let gameDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        guard FileManager.default.fileExists(atPath: gameDirectory.path) else {
            AppLog.game.error("Game directory does not exist: \(gameDirectory.path)")
            return
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: gameDirectory.path)
        AppLog.game.info("Show game directory in Finder: \(game.gameName)")
    }

    /// Deletes a game and its associated files.
    /// - Parameters:
    ///   - game: The game version to delete.
    ///   - gameRepository: The game repository for record management.
    ///   - selectedItem: An optional binding to the current sidebar selection, updated after deletion.
    ///   - gameType: An optional binding set to `true` when navigating to the resource page.
    func deleteGame(
        game: GameVersionInfo,
        gameRepository: GameRepository,
        selectedItem: Binding<SidebarItem>? = nil,
        gameType: Binding<Bool>? = nil,
    ) {
        Task {
            do {
                let gameProcessManager = DIContainer.shared.core.gameProcessManager
                let gameStatusManager = DIContainer.shared.core.gameStatusManager
                let modScanner = DIContainer.shared.core.modScanner

                if gameProcessManager.isGameRunningForAnyUser(gameId: game.id) {
                    let error = GlobalError.validation(
                        i18nKey: "error.validation.game_running_cannot_delete",
                        level: .notification,
                    )
                    DIContainer.shared.core.errorHandler.handle(error)
                    return
                }

                if let selectedItem {
                    await MainActor.run {
                        if let firstGame = gameRepository.games.first(where: {
                            $0.id != game.id
                        }) {
                            selectedItem.wrappedValue = .game(firstGame.id)
                        } else {
                            selectedItem.wrappedValue = .resource(.mod)
                            gameType?.wrappedValue = true
                        }
                    }
                }

                gameProcessManager.removeGameState(gameId: game.id)
                gameStatusManager.removeGameState(gameId: game.id)

                let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
                if FileManager.default.fileExists(atPath: profileDir.path) {
                    try FileManager.default.removeItem(at: profileDir)
                } else {
                    AppLog.game.error("Game directory not found when deleting game, skipping file deletion: \(profileDir.path)")
                }

                await modScanner.clearModCache(for: game.gameName)

                try await gameRepository.deleteGame(id: game.id)

                AppLog.game.info("Successfully deleted game: \(game.gameName)")
            } catch {
                let globalError = GlobalError.fileSystem(
                    i18nKey: "error.filesystem.game_deletion_failed",
                    level: .notification,
                )
                AppLog.game.error("Failed to delete game: \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
            }
        }
    }

    /// Deletes a corrupted game entry by name, removing both the directory and database records.
    /// - Parameters:
    ///   - name: The game name to delete.
    ///   - gameRepository: The game repository for record management.
    func deleteCorruptedGame(
        name: String,
        gameRepository: GameRepository,
    ) {
        Task {
            do {
                let modScanner = DIContainer.shared.core.modScanner

                let profileDir = AppPaths.profileDirectory(gameName: name)
                if FileManager.default.fileExists(atPath: profileDir.path) {
                    try FileManager.default.removeItem(at: profileDir)
                }

                await modScanner.clearModCache(for: name)

                try await gameRepository.deleteGamesByName(name)

                AppLog.game.info("Successfully deleted corrupted game (directory + database): \(name)")
            } catch {
                let globalError = GlobalError.fileSystem(
                    i18nKey: "error.filesystem.game_deletion_failed",
                    level: .notification,
                )
                AppLog.game.error("Failed to delete corrupted game: \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
            }
        }
    }
}
