//
//  GameRuntimeState.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Running and launching state for one game and player.
@MainActor
struct GameRuntimeState {
    let gameId: String
    let userId: String?
    let sessionStore: GameSessionStore

    var isRunning: Bool {
        guard let userId else { return false }
        return sessionStore.cachedIsGameRunning(gameId: gameId, userId: userId)
    }

    var isLaunching: Bool {
        guard let userId else { return false }
        return sessionStore.isGameLaunching(gameId: gameId, userId: userId)
    }

    var isBusy: Bool {
        isRunning || isLaunching
    }

    func refresh() {
        guard let userId else { return }
        sessionStore.refreshGameStatus(gameId: gameId, userId: userId)
    }
}
