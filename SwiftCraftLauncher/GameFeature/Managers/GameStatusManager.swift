//
//  GameStatusManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tracks game running and launching states per player using process keys.
class GameStatusManager: ObservableObject {
    static let shared = GameStatusManager()
    /// Running states keyed by processKey(gameId, userId).
    @Published private var gameRunningStates: [String: Bool] = [:]
    /// Launching states keyed by processKey(gameId, userId).
    @Published private var gameLaunchingStates: [String: Bool] = [:]

    private init() { }

    func cachedIsGameRunning(gameId: String, userId: String) -> Bool {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        return gameRunningStates[key] ?? false
    }

    func syncRunningStates(for games: [GameVersionInfo], userId: String) {
        guard !games.isEmpty else { return }

        applyOnMain { [self] in
            var updated = gameRunningStates
            var changed = false
            let processManager = AppServices.gameProcessManager

            for game in games {
                let key = GameProcessManager.processKey(gameId: game.id, userId: userId)
                let actuallyRunning = processManager.isGameRunning(gameId: game.id, userId: userId)
                if updated[key] != actuallyRunning {
                    updated[key] = actuallyRunning
                    changed = true
                }
            }

            if changed {
                gameRunningStates = updated
            }
        }
    }

    func isGameRunning(gameId: String, userId: String) -> Bool {
        let actuallyRunning = AppServices.gameProcessManager.isGameRunning(gameId: gameId, userId: userId)
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)

        applyOnMain { [self] in
            updateGameStatusIfNeeded(key: key, actuallyRunning: actuallyRunning)
        }

        return actuallyRunning
    }

    private func applyOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func updateGameStatusIfNeeded(key: String, actuallyRunning: Bool) {
        if gameRunningStates[key] != actuallyRunning {
            gameRunningStates[key] = actuallyRunning
            AppLog.game.debug("Game state sync updated: \(key) -> \(actuallyRunning ? "Running" : "Stopped")")
        }
    }

    /// Force-refreshes the running state for a specific game and player.
    /// - Parameters:
    ///   - gameId: The game identifier.
    ///   - userId: The player identifier.
    func refreshGameStatus(gameId: String, userId: String) {
        let actuallyRunning = AppServices.gameProcessManager.isGameRunning(gameId: gameId, userId: userId)
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        applyOnMain { [weak self] in
            guard let self else { return }
            gameRunningStates[key] = actuallyRunning
            AppLog.game.debug("Force refresh game state: \(key) -> \(actuallyRunning ? "Running" : "Stopped")")
        }
    }

    /// Updates the running state for a specific game and player.
    /// - Parameters:
    ///   - gameId: The game identifier.
    ///   - userId: The player identifier.
    ///   - isRunning: Whether the game is currently running.
    func setGameRunning(gameId: String, userId: String, isRunning: Bool) {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        applyOnMain { [weak self] in
            guard let self else { return }
            let currentState = gameRunningStates[key]
            if currentState != isRunning {
                gameRunningStates[key] = isRunning
                AppLog.game.debug("Game state updated: \(key) -> \(isRunning ? "Running" : "Stopped")")
            }
        }
    }

    /// Removes cached states for games that are no longer running.
    func cleanupStoppedGames() {
        let processManager = AppServices.gameProcessManager

        applyOnMain { [weak self] in
            guard let self else { return }
            gameRunningStates = gameRunningStates.filter { key, isRunning in
                guard isRunning else { return false }
                if let idx = key.firstIndex(of: "_") {
                    let gameId = String(key[..<idx])
                    let userId = String(key[key.index(after: idx)...])
                    return processManager.isGameRunning(gameId: gameId, userId: userId)
                }
                return false
            }
        }
    }

    /// A list of process keys for games that are currently running.
    var runningProcessKeys: [String] {
        gameRunningStates.compactMap { key, isRunning in
            isRunning ? key : nil
        }
    }

    /// All cached game states keyed by processKey.
    var allGameStates: [String: Bool] {
        gameRunningStates
    }

    /// Updates the launching state for a specific game and player.
    /// - Parameters:
    ///   - gameId: The game identifier.
    ///   - userId: The player identifier.
    ///   - isLaunching: Whether the game is currently launching.
    func setGameLaunching(gameId: String, userId: String, isLaunching: Bool) {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        applyOnMain { [weak self] in
            guard let self else { return }
            let currentState = gameLaunchingStates[key] ?? false
            if currentState != isLaunching {
                gameLaunchingStates[key] = isLaunching
                AppLog.game.debug("Game launch state updated: \(key) -> \(isLaunching ? "Launching" : "Not launching")")
            }
        }
    }

    /// Returns whether the specified game is currently launching.
    /// - Parameters:
    ///   - gameId: The game identifier.
    ///   - userId: The player identifier.
    /// - Returns: `true` if the game is launching.
    func isGameLaunching(gameId: String, userId: String) -> Bool {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        return gameLaunchingStates[key] ?? false
    }

    /// Removes all cached states for a specific game across all players.
    /// - Parameter gameId: The game identifier.
    func removeGameState(gameId: String) {
        let prefix = "\(gameId)_"
        applyOnMain { [weak self] in
            guard let self else { return }
            let keysToRemove = gameRunningStates.keys.filter { $0.hasPrefix(prefix) }
                + gameLaunchingStates.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                gameRunningStates.removeValue(forKey: key)
                gameLaunchingStates.removeValue(forKey: key)
            }
        }
    }
}
