//
//  GameMoreMenu.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import AppKit

/// Displays a context menu with additional actions for the selected game.
struct GameMoreMenu: View {
    let game: GameVersionInfo

    @Environment(\.openSettings)
    private var openSettings
    @EnvironmentObject private var detailState: ResourceDetailState
    @ObservedObject private var selectedGameManager: SelectedGameManager
    @ObservedObject private var gameDialogsPresenter: GameDialogsPresenter

    init(
        game: GameVersionInfo,
        selectedGameManager: SelectedGameManager = AppServices.selectedGameManager,
        gameDialogsPresenter: GameDialogsPresenter = AppServices.gameDialogsPresenter
    ) {
        self.game = game
        _selectedGameManager = ObservedObject(wrappedValue: selectedGameManager)
        _gameDialogsPresenter = ObservedObject(wrappedValue: gameDialogsPresenter)
    }

    var body: some View {
        Menu {
            if game.modLoader != GameLoader.vanilla.displayName {
                Button {
                    gameDialogsPresenter.presentModPackExport(for: game)
                } label: {
                    Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
                }
            }

            Button {
                selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
                openSettings()
            } label: {
                Label(
                    "settings.game.advanced".localized(),
                    systemImage: "gearshape"
                )
            }

            Divider()

            Button(role: .destructive) {
                gameDialogsPresenter.requestGameDeletion(of: game)
            } label: {
                Label("sidebar.context_menu.delete_game".localized(), systemImage: "trash")
            }
        } label: {
            Label("more".localized(), systemImage: "gearshape")
        }
        .help("more".localized())
    }
}
