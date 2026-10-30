//
//  GameSessionStore.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Owns game processes and their running/launching states, plus crash detection.
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

    /// `nonisolated` so database lookups can run off the main actor.
    nonisolated private let gameDatabase = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)

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

    func isGameRunningForAnyUser(gameId: String) -> Bool {
        let prefix = "\(gameId)_"
        return sessions.contains { key, session in
            key.hasPrefix(prefix) && session.process?.isRunning == true
        }
    }

    func isGameLaunching(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return sessions[key]?.isLaunching ?? false
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
        guard sessions[key]?.isRunning != isRunning else { return }
        guard sessions[key] != nil || isRunning else { return }

        sessions[key, default: Session()].isRunning = isRunning
        AppLog.game.debug("Game state updated: \(key) -> \(isRunning ? "Running" : "Stopped")")
    }

    func storeProcess(gameId: String, userId: String, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                await self?.handleProcessTermination(gameId: gameId, userId: userId, process: process)
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

    private func handleProcessTermination(gameId: String, userId: String, process: Process) async {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let wasManuallyStopped = sessions[key]?.isManuallyStopped ?? false

        handleProcessExit(gameId: gameId, wasManuallyStopped: wasManuallyStopped)

        if !wasManuallyStopped {
            let isCrash = await checkIfCrash(gameId: gameId, process: process)

            if isCrash {
                let gameSettings = DIContainer.shared.ui.gameSettingsManager
                if gameSettings.enableAICrashAnalysis {
                    AppLog.game.info("Detected game crash, enabling AI analysis: \(gameId)")
                    await collectLogsForGameImmediately(gameId: gameId)
                } else {
                    let gameDirectory = CommonUtil.gameDirectory(for: gameId)
                    NotificationCenter.default.post(
                        name: .gameCrashed,
                        object: nil,
                        userInfo: ["directory": gameDirectory as Any],
                    )
                }
            } else {
                AppLog.game.debug("Game exited normally, not triggering AI analysis: \(gameId)")
            }
        }

        sessions.removeValue(forKey: key)
    }

    /// Runs off the main actor because it performs database and file-system I/O.
    /// Crash reports are checked first because the JVM may write one even when
    /// it exits with status 0.
    nonisolated private func checkIfCrash(gameId: String, process: Process) async -> Bool {
        if let crashReport = recentCrashReport(for: gameId) {
            AppLog.game.info("Game crashed, found crash report \(crashReport): \(gameId)")
            return true
        }

        let exitCode = process.terminationStatus
        if exitCode == 0 {
            AppLog.game.debug("Game exited normally with no recent crash report: \(gameId)")
            return false
        }

        let reason = process.terminationReason == .uncaughtSignal
            ? "uncaught signal \(exitCode)"
            : "exit status \(exitCode)"
        AppLog.game.info("Game exited abnormally (\(reason)), treating as crash: \(gameId)")
        return true
    }

    /// Returns the name of a crash report created in the last five minutes, if any.
    nonisolated private func recentCrashReport(for gameId: String) -> String? {
        try? gameDatabase.initialize()
        guard let game = try? gameDatabase.getGame(by: gameId) else {
            AppLog.game.error("Unable to find game in database, unable to check crash reports: \(gameId)")
            return nil
        }

        let crashReportsDir = AppPaths.profileDirectory(gameName: game.gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.crashReports, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: crashReportsDir,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
            options: [.skipsHiddenFiles],
        )) ?? []

        let cutoff = Date().addingTimeInterval(-300)
        return files.first { url in
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey]),
                  values.isRegularFile ?? false,
                  let created = values.creationDate
            else {
                return false
            }
            return created >= cutoff
        }?.lastPathComponent
    }

    /// Runs off the main actor because it performs database I/O.
    nonisolated private func collectLogsForGameImmediately(gameId: String) async {
        do {
            try? gameDatabase.initialize()
            guard let game = try gameDatabase.getGame(by: gameId) else {
                AppLog.game.error("Unable to find game in database: \(gameId)")
                return
            }

            await DIContainer.shared.core.gameLogCollector.collectAndOpenAIWindow(gameName: game.gameName)
        } catch {
            AppLog.game.error("Failed to query game from database: \(error.localizedDescription)")
        }
    }

    private func handleProcessExit(gameId: String, wasManuallyStopped: Bool) {
        if wasManuallyStopped {
            AppLog.game.debug("Game stopped by user: \(gameId)")
        } else {
            AppLog.game.info("Game process exited: \(gameId)")
        }
    }
}
