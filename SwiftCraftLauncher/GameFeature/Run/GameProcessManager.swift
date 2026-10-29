//
//  GameProcessManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages running game processes and tracks their lifecycle.
@MainActor
@Observable
final class GameProcessManager {
    static func processKey(gameId: String, userId: String) -> String {
        "\(gameId)_\(userId)"
    }

    private var gameProcesses: [String: Process] = [:]
    private var manuallyStoppedGames: Set<String> = []

    /// `nonisolated` so database lookups can run off the main actor.
    nonisolated private let gameDatabase = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)

    init() { }

    func storeProcess(gameId: String, userId: String, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                await self?.handleProcessTermination(gameId: gameId, userId: userId, process: process)
            }
        }

        gameProcesses[key] = process
        AppLog.game.debug("Stored game process: \(key)")
    }

    private func handleProcessTermination(gameId: String, userId: String, process: Process) async {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let wasManuallyStopped = manuallyStoppedGames.contains(key)

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

        DIContainer.shared.core.gameStatusManager.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
        gameProcesses.removeValue(forKey: key)
        manuallyStoppedGames.remove(key)
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
    nonisolated func collectLogsForGameImmediately(gameId: String) async {
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

    func stopProcess(for gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        guard let process = gameProcesses[key] else { return false }
        manuallyStoppedGames.insert(key)

        if process.isRunning {
            process.terminate()
            Task.detached(priority: .utility) {
                process.waitUntilExit()
            }
        }

        AppLog.game.debug("Stopping game process: \(key)")
        return true
    }

    func isGameRunning(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return gameProcesses[key]?.isRunning ?? false
    }

    func isGameRunningForAnyUser(gameId: String) -> Bool {
        let prefix = "\(gameId)_"
        return gameProcesses.contains { key, proc in key.hasPrefix(prefix) && proc.isRunning }
    }

    func removeGameState(gameId: String) {
        let prefix = "\(gameId)_"
        let toRemove = gameProcesses.filter { key, _ in key.hasPrefix(prefix) }
        for (key, process) in toRemove {
            gameProcesses.removeValue(forKey: key)
            if process.isRunning {
                manuallyStoppedGames.insert(key)
            }
        }

        for (key, process) in toRemove where process.isRunning {
            process.terminate()
            Task { @MainActor [weak self] in
                await Task.detached(priority: .utility) {
                    process.waitUntilExit()
                }.value
                self?.gameProcesses.removeValue(forKey: key)
                self?.manuallyStoppedGames.remove(key)
            }
        }

        for (key, process) in toRemove where !process.isRunning {
            if let idx = key.firstIndex(of: "_") {
                let gameId = String(key[..<idx])
                let userId = String(key[key.index(after: idx)...])
                DIContainer.shared.core.gameStatusManager.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
            }
        }
    }
}
