//
//  GameActionButtons.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Provides action buttons for the selected game: launch/stop, show in Finder, import, and crash alert handling.
struct GameActionButtons: View {
    @Environment(DIContainer.self)
    private var container
    let game: GameVersionInfo
    @Environment(\.controlActiveState)
    private var controlActiveState

    @Environment(ResourceDetailState.self)
    private var detailState
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(GameLaunchUseCase.self)
    private var gameLaunchUseCase
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @State private var activeAlert: ResourceButtonAlertType?

    init(
        game: GameVersionInfo,
    ) {
        self.game = game
    }

    private var currentUserId: String {
        playerListViewModel.currentPlayer?.id ?? ""
    }

    private func cachedIsGameRunning(userId: String = "") -> Bool {
        container.core.gameStatusManager.cachedIsGameRunning(
            gameId: game.id,
            userId: userId.isEmpty ? currentUserId : userId,
        )
    }

    var body: some View {
        Group {
            Button {
                Task {
                    let userId = currentUserId
                    let isRunning = container.core.gameStatusManager.isGameRunning(gameId: game.id, userId: userId)
                    if isRunning {
                        guard let player = playerListViewModel.currentPlayer else { return }
                        await gameLaunchUseCase.stopGame(player: player, game: game)
                    } else {
                        guard let player = playerListViewModel.currentPlayer else {
                            activeAlert = .noPlayerForLaunch
                            return
                        }

                        container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                        defer { container.core.gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                        await gameLaunchUseCase.launchGame(
                            player: player,
                            game: game,
                        )
                    }
                }
            } label: {
                let userId = currentUserId
                let isRunning = cachedIsGameRunning(userId: userId)
                let isLaunchingGame = container.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)
                if isLaunchingGame, !isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(
                        isRunning
                            ? "common.stop".localized()
                            : "play.fill".localized(),
                        systemImage: isRunning
                            ? "stop.fill" : "play.fill",
                    )
                    .applyReplaceTransition()
                }
            }
            .id(controlActiveState)
            .help(
                cachedIsGameRunning()
                    ? "common.stop"
                    : (container.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: currentUserId) ? "" : "play.fill"),
            )
            .disabled(container.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: currentUserId))

            if detailState.gameType == false, game.modLoader != GameLoader.vanilla.displayName {
                ResourceImportButton(
                    game: game,
                    gameResourcesType: detailState.gameResourcesType,
                )
            }

            Button {
                container.core.gameActionManager.showInFinder(game: game)
            } label: {
                Label("game.path".localized(), systemImage: "folder")
            }
            .help("game.path".localized())

            GameMoreMenu(game: game)
                .alert(item: $activeAlert) { alertType in
                    alertType.alert
                }
        }
        .gameCrashAlert()
        .onAppear {
            container.core.gameStatusManager.refreshGameStatus(gameId: game.id, userId: currentUserId)
        }
        .onChange(of: currentUserId) { _, newUserId in
            container.core.gameStatusManager.refreshGameStatus(gameId: game.id, userId: newUserId)
        }
    }
}
