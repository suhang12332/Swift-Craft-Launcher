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

    let openSettings: () -> Void
    let openGameDeletion: (GameVersionInfo) -> Void
    let openModPackExport: (GameVersionInfo) -> Void

    var body: some View {
        if !gameRepository.games.isEmpty {
            Text("sidebar.games.title")
                .font(.headline)
            ForEach(gameRepository.games) { game in
                Menu {
                    GameContextMenu(
                        game: game,
                        onDelete: { openGameDeletion(game) },
                        onOpenSettings: { openSettings() },
                        onExport: { openModPackExport(game) },
                        showsShowInLauncher: true
                    )
                    .environmentObject(playerListViewModel)
                    .environmentObject(gameRepository)
                    .environmentObject(gameLaunchUseCase)
                } label: {
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
            AIChatManager.shared.openChatWindow()
        }

        Button("menu.quit".localized()) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
