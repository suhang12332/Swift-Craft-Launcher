//
//  GameActionButtons.swift
//  MainFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Provides action buttons for the selected game: launch/stop, show in Finder, import, and crash alert handling.
struct GameActionButtons: View {
    let game: GameVersionInfo
    @Environment(\.controlActiveState)
    private var controlActiveState

    @Environment(ResourceDetailState.self)
    private var detailState
    @Environment(GameActionsProvider.self)
    private var gameActionsProvider
    @Environment(\.openSettings)
    private var openSettings

    private var actions: GameActions {
        gameActionsProvider.actions(for: game)
    }

    var body: some View {
        let gameActions = actions

        Group {
            Button(action: gameActions.toggleGameState) {
                switch gameActions.status {
                case .launching:
                    ProgressView()
                        .controlSize(.small)
                case .running:
                    Label("common.stop".localized(), systemImage: "stop.fill")
                        .applyReplaceTransition()
                case .stopped:
                    Label("play.fill".localized(), systemImage: "play.fill")
                        .applyReplaceTransition()
                }
            }
            .id(controlActiveState)
            .help(
                gameActions.status == .running
                    ? "common.stop"
                    : (gameActions.status == .launching ? "" : "play.fill"),
            )
            .disabled(gameActions.isLaunching)

            if detailState.gameType == false,
               detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue
               || gameActions.isModded {
                ResourceImportButton(
                    game: game,
                    gameResourcesType: detailState.gameResourcesType,
                )
            }

            Button(action: gameActions.showInFinder) {
                Label("game.path".localized(), systemImage: "folder")
            }
            .help("game.path".localized())

            Menu {
                GameContextMenu(game: game, placement: .toolbar) {
                    openSettings()
                }
            } label: {
                Label("more".localized(), systemImage: "hand.tap")
            }
            .help("more".localized())
        }
        .onAppear {
            actions.refreshStatus()
        }
        .onChange(of: gameActions.userId) { _, _ in
            actions.refreshStatus()
        }
    }
}
