//
//  MenuBarExtraContentView.swift
//  Swift Craft Launcher
//
//  Created by Codex on 2026/4/20.
//

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

    private func gameStatusSymbolName(for game: GameVersionInfo) -> String {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        let isRunning = gameStatusManager.isGameRunning(gameId: game.id, userId: userId)
        let isLaunching = gameStatusManager.isGameLaunching(gameId: game.id, userId: userId)

        if isLaunching && !isRunning {
            return "progress.indicator"
        } else if isRunning {
            return "stop.fill"
        } else {
            return "play.fill"
        }
    }

    var body: some View {
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
                        showsShowInLauncher: true
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
}
