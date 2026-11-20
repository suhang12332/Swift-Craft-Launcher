//
//  GameSessionStore.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Owns game processes and their running/launching states, plus abnormal-exit detection.
@MainActor
@Observable
final class GameSessionStore {
    private struct Session {
        var process: Process?
        var isRunning = false
        var isLaunching = false
        var isManuallyStopped = false
    }

    private var sessions: [String: Session] = [:]

    /// The game directory of the most recent abnormal exit waiting to be presented.
    var pendingCrashDirectory: URL?

    init() { }

    private static func processKey(gameId: String, userId: String) -> String {
        "\(gameId)_\(userId)"
    }

    func cachedIsGameRunning(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return sessions[key]?.isRunning ?? false
    }

    /// Refreshes the cached running state from the process and returns the actual state.
    @discardableResult
    func refreshGameStatus(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let actuallyRunning = sessions[key]?.process?.isRunning ?? false
        updateRunningState(actuallyRunning, forKey: key)
        return actuallyRunning
    }

    func isGameActiveForAnyUser(gameId: String) -> Bool {
        let prefix = "\(gameId)_"
        return sessions.contains { key, session in
            guard key.hasPrefix(prefix) else { return false }
            return session.process?.isRunning == true || session.isLaunching
        }
    }

    func isGameLaunching(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return sessions[key]?.isLaunching ?? false
    }

    func markProcessRunning(gameId: String, userId: String, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        guard sessions[key]?.process === process else { return }
        updateRunningState(true, forKey: key)
    }

    func setGameRunning(gameId: String, userId: String, isRunning: Bool) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        updateRunningState(isRunning, forKey: key)
    }

    func setGameLaunching(gameId: String, userId: String, isLaunching: Bool) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        guard sessions[key]?.isLaunching != isLaunching else { return }
        guard sessions[key] != nil || isLaunching else { return }

        sessions[key, default: Session()].isLaunching = isLaunching
        AppLog.game.debug("Game launch state updated: \(key) -> \(isLaunching ? "Launching" : "Not launching")")
    }

    private func updateRunningState(_ isRunning: Bool, forKey key: String) {
        guard let session = sessions[key] else { return }
        guard session.isRunning != isRunning else { return }

        sessions[key, default: Session()].isRunning = isRunning
        AppLog.game.debug("Game state updated: \(key) -> \(isRunning ? "Running" : "Stopped")")
    }

    func storeProcess(gameId: String, userId: String, gameDirectory: URL, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleProcessTermination(
                    gameId: gameId,
                    userId: userId,
                    gameDirectory: gameDirectory,
                    process: process,
                )
            }
        }

        var session = sessions[key, default: Session()]
        session.process = process
        session.isRunning = false
        session.isManuallyStopped = false
        sessions[key] = session
        AppLog.game.debug("Stored game process: \(key)")
    }

    func stopProcess(for gameId: String, userId: String) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        guard var session = sessions[key], let process = session.process else { return }

        if process.isRunning {
            session.isManuallyStopped = true
            sessions[key] = session
            process.terminate()
            Task.detached(priority: .utility) {
                process.waitUntilExit()
            }
        } else {
            sessions.removeValue(forKey: key)
        }

        AppLog.game.debug("Stopping game process: \(key)")
    }

    func removeGameState(gameId: String) {
        let prefix = "\(gameId)_"
        for key in sessions.keys.filter({ $0.hasPrefix(prefix) }) {
            guard var session = sessions[key] else { continue }

            session.isRunning = false
            session.isLaunching = false
            guard let process = session.process, process.isRunning else {
                sessions.removeValue(forKey: key)
                continue
            }

            session.process = nil
            session.isManuallyStopped = true
            sessions[key] = session
            process.terminate()
            Task.detached(priority: .utility) {
                process.waitUntilExit()
            }
        }
    }

    private func handleProcessTermination(
        gameId: String,
        userId: String,
        gameDirectory: URL,
        process: Process,
    ) {
        let key = Self.processKey(gameId: gameId, userId: userId)

        // Ignore stale callbacks from a process that has already been replaced by
        // a newer launch for the same game and user.
        guard let session = sessions[key], session.process === process else {
            return
        }

        let wasManuallyStopped = session.isManuallyStopped
        sessions.removeValue(forKey: key)

        if wasManuallyStopped {
            AppLog.game.debug("Game stopped by user: \(gameId)")
            return
        }

        guard Self.didExitAbnormally(
            reason: process.terminationReason,
            status: process.terminationStatus,
        ) else {
            AppLog.game.debug("Game exited normally: \(gameId)")
            return
        }

        let reason = Self.terminationDescription(for: process)
        AppLog.game.info("Game exited abnormally (\(reason)): \(gameId)")

        pendingCrashDirectory = gameDirectory
    }

    /// Determines whether a terminated process ended abnormally.
    ///
    /// Crash reports are diagnostics, not reliable evidence of a crash, so this
    /// relies only on the operating system's process termination status.
    static func didExitAbnormally(reason: Process.TerminationReason, status: Int32) -> Bool {
        if reason == .uncaughtSignal {
            return true
        }
        return status != 0
    }

    private static func terminationDescription(for process: Process) -> String {
        if process.terminationReason == .uncaughtSignal {
            return "uncaught signal \(process.terminationStatus)"
        }
        return "exit status \(process.terminationStatus)"
    }
}
