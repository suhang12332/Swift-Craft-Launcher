//
//  MenuBarExtraContentView.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Content view for the macOS menu bar extra, listing games, players, and app actions.

import AppKit
import SwiftUI

struct MenuBarExtraContentView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(GameLaunchUseCase.self)
    private var gameLaunchUseCase

    let openSettings: () -> Void

    /// Returns the SF Symbol name reflecting the game's current launch or running state.
    private func gameStatusSymbolName(for game: GameVersionInfo) -> String {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let isRunning = container.core.gameStatusManager.cachedIsGameRunning(gameId: game.id, userId: userId)
        let isLaunching = container.core.gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)

        if isLaunching, !isRunning {
            return "progress.indicator"
        } else if isRunning {
            return "stop.fill"
        } else {
            return "play.fill"
        }
    }

    var body: some View {
        Group {
            gamesSection
            Divider()
            playersSection
            Divider()
            Button("ai.assistant.title".localized()) {
                container.ui.aiChatManager.openChatWindow()
            }
            Button("menu.quit".localized()) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onAppear(perform: syncMenuBarGameStatuses)
        .onChange(of: playerListViewModel.currentPlayer?.id) { _, _ in
            syncMenuBarGameStatuses()
        }
        .onChange(of: gameRepository.games.count) { _, _ in
            syncMenuBarGameStatuses()
        }
    }

    @ViewBuilder private var gamesSection: some View {
        if !gameRepository.games.isEmpty {
            Text("sidebar.games.title".localized())
                .font(.headline)
            ForEach(gameRepository.games) { game in
                gameMenu(for: game)
            }
        }
    }

    @ViewBuilder
    private func gameMenu(for game: GameVersionInfo) -> some View {
        let contextMenu = GameContextMenu(
            game: game,
            onDelete: { container.ui.gameDialogsPresenter.requestGameDeletion(of: game) },
            onOpenSettings: { openSettings() },
            onExport: { container.ui.gameDialogsPresenter.presentModPackExport(for: game) },
            showsShowInLauncher: true,
        )
        Menu {
            contextMenu
        } label: {
            Image(systemName: gameStatusSymbolName(for: game))
            Text(game.gameName)
        }
    }

    @ViewBuilder private var playersSection: some View {
        if !playerListViewModel.players.isEmpty {
            Text("menu.player.list".localized())
                .font(.headline)
            if let currentPlayer = playerListViewModel.currentPlayer {
                Menu(currentPlayer.name) {
                    let otherPlayers = playerListViewModel.players.filter { $0.id != currentPlayer.id }
                    if !otherPlayers.isEmpty {
                        ForEach(otherPlayers) { player in
                            Button {
                                playerListViewModel.setCurrentPlayer(byID: player.id)
                            } label: {
                                Label(player.name, systemImage: "person")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Synchronizes cached running states for all games.
    private func syncMenuBarGameStatuses() {
        container.core.gameStatusManager.syncRunningStates(
            for: gameRepository.games,
            userId: playerListViewModel.currentPlayer?.id ?? "",
        )
    }
}
