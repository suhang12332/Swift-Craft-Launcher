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
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase
    @EnvironmentObject private var gameStatusManager: GameStatusManager
    @EnvironmentObject private var gameActionManager: GameActionManager
    @ObservedObject private var gameDialogsPresenter: GameDialogsPresenter

    let openSettings: () -> Void
    private let aiChatManager: AIChatManager

    init(
        openSettings: @escaping () -> Void,
        gameDialogsPresenter: GameDialogsPresenter = AppServices.gameDialogsPresenter,
        aiChatManager: AIChatManager = AppServices.aiChatManager,
    ) {
        _gameDialogsPresenter = ObservedObject(wrappedValue: gameDialogsPresenter)
        self.openSettings = openSettings
        self.aiChatManager = aiChatManager
    }

    /// Returns the SF Symbol name reflecting the game's current launch or running state.
    private func gameStatusSymbolName(for game: GameVersionInfo) -> String {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let isRunning = gameStatusManager.cachedIsGameRunning(gameId: game.id, userId: userId)
        let isLaunching = gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)

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
            if !gameRepository.games.isEmpty {
                Text("sidebar.games.title".localized())
                    .font(.headline)
                ForEach(gameRepository.games) { game in
                    Menu {
                        GameContextMenu(
                            game: game,
                            onDelete: { gameDialogsPresenter.requestGameDeletion(of: game) },
                            onOpenSettings: { openSettings() },
                            onExport: { gameDialogsPresenter.presentModPackExport(for: game) },
                            showsShowInLauncher: true,
                        )
                        .environmentObject(playerListViewModel)
                        .environmentObject(gameRepository)
                        .environmentObject(gameLaunchUseCase)
                    } label: {
                        Image(systemName: gameStatusSymbolName(for: game))
                        Text(game.gameName)
                    }
                }
            }

            Divider()

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

            Divider()

            Button("ai.assistant.title".localized()) {
                aiChatManager.openChatWindow()
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

    /// Synchronizes cached running states for all games.
    private func syncMenuBarGameStatuses() {
        gameStatusManager.syncRunningStates(
            for: gameRepository.games,
            userId: playerListViewModel.currentPlayer?.id ?? "",
        )
    }
}
