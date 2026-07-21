//
//  GameContextMenu.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Context menu for game entries providing play/stop, settings, export, and delete actions.

import SwiftUI

struct GameContextMenu: View {
    @EnvironmentObject private var container: DIContainer
    let game: GameVersionInfo
    let onDelete: () -> Void
    let onOpenSettings: () -> Void
    let onExport: () -> Void
    let showsShowInLauncher: Bool

    init(
        game: GameVersionInfo,
        onDelete: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onExport: @escaping () -> Void,
        showsShowInLauncher: Bool = false,
    ) {
        self.game = game
        self.onDelete = onDelete
        self.onOpenSettings = onOpenSettings
        self.onExport = onExport
        self.showsShowInLauncher = showsShowInLauncher
    }

    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var gameLaunchUseCase: GameLaunchUseCase
    @State private var actionViewModel = GameContextMenuActionViewModel()

    /// Whether the game is currently running, determined by cached process state.
    private var isRunning: Bool {
        let userId = playerListViewModel.currentPlayer?.id ?? ""
        return container.core.gameStatusManager.cachedIsGameRunning(gameId: game.id, userId: userId)
    }

    var body: some View {
        Button(action: {
            toggleGameState()
        }, label: {
            Label(
                isRunning ? "stop.fill".localized() : "play.fill".localized(),
                systemImage: isRunning ? "stop.fill" : "play.fill",
            )
        }).disabled(playerListViewModel.currentPlayer == nil)

        Button(action: {
            container.core.gameActionManager.showInFinder(game: game)
        }, label: {
            Label("sidebar.context_menu.show_in_finder".localized(), systemImage: "folder")
        })

        if showsShowInLauncher {
            Button(action: {
                container.core.selectedGameManager.setSelectedGame(game.id)
                container.ui.windowManager.showAndActivateMainWindow()
            }, label: {
                Label("sidebar.context_menu.show_in_launcher".localized(), systemImage: "macwindow")
            })
        }

        Button(action: {
            container.core.selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
            container.ui.windowManager.showAndActivateMainWindow()
            onOpenSettings()
        }, label: {
            Label("settings.game.advanced".localized(), systemImage: "gearshape")
        })

        Divider()

        if game.modLoader != GameLoader.vanilla.displayName {
            Button(action: {
                if showsShowInLauncher {
                    container.ui.windowManager.showAndActivateMainWindow()
                }
                onExport()
            }, label: {
                Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
            })
        }

        Button(action: {
            if showsShowInLauncher {
                container.ui.windowManager.showAndActivateMainWindow()
            }
            onDelete()
        }, label: {
            Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
        })
    }

    /// Toggles the game between running and stopped states.
    private func toggleGameState() {
        actionViewModel.toggleGameState(
            isRunning: isRunning,
            player: playerListViewModel.currentPlayer,
            game: game,
            gameLaunchUseCase: gameLaunchUseCase,
        )
    }
}
