//
//  GameContextMenu.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Menu content shared by the sidebar context menu, menu bar extra, and toolbar more menu.

import SwiftUI

/// Where a game menu is presented, controlling scene-specific entries.
enum GameMenuPlacement {
    case sidebar
    case menuBarExtra
    case toolbar
}

struct GameContextMenu: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(GameActionsProvider.self)
    private var gameActionsProvider

    let game: GameVersionInfo
    var placement: GameMenuPlacement = .sidebar
    let onOpenSettings: () -> Void

    private var showsLaunchControls: Bool {
        placement != .toolbar
    }

    var body: some View {
        let gameActions = gameActionsProvider.actions(for: game)

        if showsLaunchControls {
            Button(action: gameActions.toggleGameState) {
                Label(
                    gameActions.isRunning ? "common.stop".localized() : "play.fill".localized(),
                    systemImage: gameActions.isRunning ? "stop.fill" : "play.fill",
                )
            }
            .disabled(!gameActions.canLaunch)

            Button(action: gameActions.showInFinder) {
                Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
            }

            if placement == .menuBarExtra {
                Button(action: gameActions.showInLauncher) {
                    Label("sidebar.context_menu.show_in_launcher".localized(), systemImage: "macwindow")
                }
            }

            Divider()
        }

        Button {
            activateMainWindowIfNeeded()
            gameActions.openAdvancedSettings(openSettings: onOpenSettings)
        } label: {
            Label("settings.game.advanced".localized(), systemImage: "gearshape")
        }

        if gameActions.isModded {
            Button {
                activateMainWindowIfNeeded()
                gameActions.presentModDependencyGraph()
            } label: {
                Label(
                    "mod.dependency_graph.title".localized(),
                    systemImage: "point.3.connected.trianglepath.dotted",
                )
            }
        }

        if !CommonUtil.isMinecraftSnapshotVersion(game.gameVersion) {
            Button {
                activateMainWindowIfNeeded()
                gameActions.presentLoaderUpdate()
            } label: {
                Label("game.loader.update.title".localized(), systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(gameActions.isBusy)
        }

        Button {
            activateMainWindowIfNeeded()
            gameActions.presentLoaderUpdate(mode: .repair)
        } label: {
            Label("game.repair.title".localized(), systemImage: "wrench.and.screwdriver")
        }
        .disabled(gameActions.isBusy)

        if gameActions.isModded {
            Button {
                activateMainWindowIfNeeded()
                gameActions.presentModPackExport()
            } label: {
                Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Button(role: .destructive) {
            activateMainWindowIfNeeded()
            gameActions.requestDeletion()
        } label: {
            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
        }
    }

    private func activateMainWindowIfNeeded() {
        if placement == .menuBarExtra {
            container.ui.windowManager.showAndActivateMainWindow()
        }
    }
}
