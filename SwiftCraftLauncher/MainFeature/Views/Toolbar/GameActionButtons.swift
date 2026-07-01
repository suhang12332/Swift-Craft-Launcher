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
    let game: GameVersionInfo
    @Environment(\.controlActiveState)
    private var controlActiveState

    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameStatusManager: GameStatusManager
    @EnvironmentObject private var gameActionManager: GameActionManager
    @ObservedObject private var gameDialogsPresenter: GameDialogsPresenter
    @State private var showCrashAlert = false
    @State private var crashDirectory: URL?
    @State private var activeAlert: ResourceButtonAlertType?

    init(
        game: GameVersionInfo,
        gameDialogsPresenter: GameDialogsPresenter = AppServices.gameDialogsPresenter,
    ) {
        self.game = game
        _gameDialogsPresenter = ObservedObject(wrappedValue: gameDialogsPresenter)
    }

    private var currentUserId: String {
        playerListViewModel.currentPlayer?.id ?? ""
    }

    private func cachedIsGameRunning(userId: String = "") -> Bool {
        gameStatusManager.cachedIsGameRunning(
            gameId: game.id,
            userId: userId.isEmpty ? currentUserId : userId,
        )
    }

    var body: some View {
        Group {
            Button {
                Task {
                    let userId = currentUserId
                    let isRunning = gameStatusManager.isGameRunning(gameId: game.id, userId: userId)
                    if isRunning {
                        await gameLaunchUseCase.stopGame(player: playerListViewModel.currentPlayer, game: game)
                    } else {
                        if playerListViewModel.currentPlayer == nil {
                            activeAlert = .noPlayerForLaunch
                            return
                        }

                        gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: true)
                        defer { gameStatusManager.setGameLaunching(gameId: game.id, userId: userId, isLaunching: false) }
                        await gameLaunchUseCase.launchGame(
                            player: playerListViewModel.currentPlayer,
                            game: game,
                        )
                    }
                }
            } label: {
                let userId = currentUserId
                let isRunning = cachedIsGameRunning(userId: userId)
                let isLaunchingGame = gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)
                if isLaunchingGame, !isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(
                        isRunning
                        ? "stop.fill".localized()
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
                ? "stop.fill"
                : (gameStatusManager.isGameLaunching(gameId: game.id, userId: currentUserId) ? "" : "play.fill"),
            )
            .disabled(gameStatusManager.isGameLaunching(gameId: game.id, userId: currentUserId))

            if detailState.gameType == false, game.modLoader != GameLoader.vanilla.displayName {
                ResourceImportButton(
                    game: game,
                    gameResourcesType: detailState.gameResourcesType,
                )
            }

            Button {
                gameActionManager.showInFinder(game: game)
            } label: {
                Label("game.path".localized(), systemImage: "folder")
            }
            .help("game.path".localized())

            GameMoreMenu(game: game)
            .alert(item: $activeAlert) { alertType in
                alertType.alert
            }
            .alert(
                "error.game_launch.game_crashed".localized(),
                isPresented: $showCrashAlert,
            ) {
                Button("menu.open.log".localized()) {
                    if let directory = crashDirectory {
                        NSWorkspace.shared.open(directory)
                    } else {
                        AppLog.main.error("无法打开游戏目录：directory 为空")
                    }
                }
                Button("common.close".localized(), role: .cancel) { }
            } message: {
                Text("error.game_launch.game_crashed.description".localized())
            }
            .onReceive(NotificationCenter.default.publisher(for: .gameCrashed)) { notification in
                let directory = notification.userInfo?["directory"] as? URL
                crashDirectory = directory
                showCrashAlert = true
            }
        }
        .onAppear {
            gameStatusManager.refreshGameStatus(gameId: game.id, userId: currentUserId)
        }
        .onChange(of: currentUserId) { _, newUserId in
            gameStatusManager.refreshGameStatus(gameId: game.id, userId: newUserId)
        }
    }
}
