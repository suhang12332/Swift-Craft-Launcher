//
//  GameActions.swift
//  MainFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

// Command facade exposing one game's runtime state and actions to every UI surface.

import Foundation

enum GameStatus {
    case stopped
    case launching
    case running
}

/// Per-game commands and runtime state shared by menus, toolbar buttons, and the Touch Bar.
@MainActor
struct GameActions {
    let game: GameVersionInfo
    let container: DIContainer
    let gameLaunchUseCase: GameLaunchUseCase
    let player: Player?
    let userId: String?
    let state: GameRuntimeState

    init(
        game: GameVersionInfo,
        container: DIContainer,
        gameLaunchUseCase: GameLaunchUseCase,
        player: Player?,
    ) {
        self.game = game
        self.container = container
        self.gameLaunchUseCase = gameLaunchUseCase
        self.player = player

        let userId = player?.id
        self.userId = userId
        state = GameRuntimeState(
            gameId: game.id,
            userId: userId,
            sessionStore: container.core.gameSessionStore,
        )
    }

    var canLaunch: Bool {
        player != nil
    }

    var isRunning: Bool {
        state.isRunning
    }

    var isLaunching: Bool {
        state.isLaunching
    }

    var isBusy: Bool {
        state.isBusy
    }

    var status: GameStatus {
        if isLaunching, !isRunning {
            return .launching
        }
        if isRunning {
            return .running
        }
        return .stopped
    }

    var isModded: Bool {
        game.modLoader != GameLoader.vanilla.displayName
    }

    func refreshStatus() {
        state.refresh()
    }

    func toggleGameState() {
        Task {
            await gameLaunchUseCase.toggleGameState(player: player, game: game)
        }
    }

    func showInFinder() {
        container.core.gameActionManager.showInFinder(game: game)
    }

    func showInLauncher() {
        container.core.selectedGameManager.setSelectedGame(game.id)
        container.ui.windowManager.showAndActivateMainWindow()
    }

    func openAdvancedSettings(openSettings: () -> Void) {
        container.core.selectedGameManager.setSelectedGameAndOpenAdvancedSettings(game.id)
        openSettings()
    }

    func presentModPackExport() {
        container.ui.gameDialogsPresenter.presentModPackExport(for: game)
    }

    func presentLoaderUpdate(mode: GameLoaderUpdateMode = .adjust) {
        container.ui.gameDialogsPresenter.presentLoaderUpdate(for: game, mode: mode)
    }

    func presentModDependencyGraph() {
        container.ui.windowManager.presentModDependencyGraph(for: game)
    }

    func requestDeletion() {
        container.ui.gameDialogsPresenter.requestGameDeletion(of: game)
    }
}
