//
//  GameActionManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Provides game-related actions such as revealing in Finder and deletion.
@MainActor
class GameActionManager: ObservableObject {
    static let shared = GameActionManager()

    private init() { }

    /// Reveals the game directory in Finder.
    /// - Parameter game: The game version to locate.
    func showInFinder(game: GameVersionInfo) {
        let gameDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        guard FileManager.default.fileExists(atPath: gameDirectory.path) else {
            Logger.shared.warning("游戏目录不存在: \(gameDirectory.path)")
            return
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: gameDirectory.path)
        Logger.shared.info("在访达中显示游戏目录: \(game.gameName)")
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
                let gameProcessManager = AppServices.gameProcessManager
                let gameStatusManager = AppServices.gameStatusManager
                let modScanner = AppServices.modScanner

                if gameProcessManager.isGameRunningForAnyUser(gameId: game.id) {
                    let error = GlobalError.validation(
                        chineseMessage: "游戏运行中，无法删除",
                        i18nKey: "error.validation.game_running_cannot_delete",
                        level: .notification,
                    )
                    AppServices.errorHandler.handle(error)
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
                    Logger.shared.warning("删除游戏时未找到游戏目录，跳过文件删除: \(profileDir.path)")
                }

                await modScanner.clearModCache(for: game.gameName)

                try await gameRepository.deleteGame(id: game.id)

                Logger.shared.info("成功删除游戏: \(game.gameName)")
            } catch {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "删除游戏失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.game_deletion_failed",
                    level: .notification,
                )
                Logger.shared.error("删除游戏失败: \(globalError.chineseMessage)")
                AppServices.errorHandler.handle(globalError)
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
                let modScanner = AppServices.modScanner

                let profileDir = AppPaths.profileDirectory(gameName: name)
                if FileManager.default.fileExists(atPath: profileDir.path) {
                    try FileManager.default.removeItem(at: profileDir)
                }

                await modScanner.clearModCache(for: name)

                try await gameRepository.deleteGamesByName(name)

                Logger.shared.info("成功删除损坏游戏（目录 + 数据库）: \(name)")
            } catch {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "删除损坏游戏失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.game_deletion_failed",
                    level: .notification,
                )
                Logger.shared.error("删除损坏游戏失败: \(globalError.chineseMessage)")
                AppServices.errorHandler.handle(globalError)
            }
        }
    }
}
