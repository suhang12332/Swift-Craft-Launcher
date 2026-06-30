//
//  GameProcessManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages running game processes and tracks their lifecycle.
final class GameProcessManager: ObservableObject, @unchecked Sendable {
    static let shared = GameProcessManager()

    static func processKey(gameId: String, userId: String) -> String {
        "\(gameId)_\(userId)"
    }

    private var gameProcesses: [String: Process] = [:]

    private var manuallyStoppedGames: Set<String> = []
    private let queue = DispatchQueue(label: "com.swiftcraftlauncher.gameprocessmanager")
    private let gameDatabase = GameVersionDatabase(dbPath: AppPaths.gameVersionDatabase.path)
    private let gameSettingsManager: GameSettingsManager

    private init(gameSettingsManager: GameSettingsManager = AppServices.gameSettingsManager) {
        self.gameSettingsManager = gameSettingsManager
    }

    func storeProcess(gameId: String, userId: String, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        process.terminationHandler = { [weak self] process in
            Task {
                await self?.handleProcessTermination(gameId: gameId, userId: userId, process: process)
            }
        }

        queue.async { [weak self] in
            self?.gameProcesses[key] = process
        }
        Logger.shared.debug("存储游戏进程: \(key)")
    }

    private func handleProcessTermination(gameId: String, userId: String, process: Process) async {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let wasManuallyStopped = queue.sync { manuallyStoppedGames.contains(key) }

        handleProcessExit(gameId: gameId, wasManuallyStopped: wasManuallyStopped)

        if !wasManuallyStopped {
            let isCrash = await checkIfCrash(gameId: gameId, process: process)

            if isCrash {
                let gameSettings = gameSettingsManager
                if gameSettings.enableAICrashAnalysis {
                    Logger.shared.info("检测到游戏崩溃，启用AI分析: \(gameId)")
                    await collectLogsForGameImmediately(gameId: gameId)
                } else {
                    let gameDirectory = CommonUtil.gameDirectory(for: gameId)
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .gameCrashed,
                            object: nil,
                            userInfo: ["directory": gameDirectory as Any],
                        )
                    }
                }
            } else {
                Logger.shared.debug("游戏正常退出，不触发AI分析: \(gameId)")
            }
        }

        await MainActor.run {
            AppServices.gameStatusManager.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
        }
        queue.async { [weak self] in
            self?.gameProcesses.removeValue(forKey: key)
            self?.manuallyStoppedGames.remove(key)
        }
    }

    private func checkIfCrash(gameId: String, process: Process) async -> Bool {
        let exitCode = process.terminationStatus
        if exitCode == 0 {
            Logger.shared.debug("游戏退出码为0: \(gameId)")
        } else {
            Logger.shared.info("游戏退出码非0 (\(exitCode))，可能是崩溃: \(gameId)")
            return true
        }

        do {
            try? gameDatabase.initialize()
            guard let game = try gameDatabase.getGame(by: gameId) else {
                Logger.shared.warning("无法从数据库找到游戏，无法检查崩溃报告: \(gameId)")
                return exitCode != 0
            }

            let gameDirectory = AppPaths.profileDirectory(gameName: game.gameName)
            let crashReportsDir = gameDirectory.appendingPathComponent(AppConstants.DirectoryNames.crashReports, isDirectory: true)
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: crashReportsDir.path) {
                do {
                    let crashFiles = try fileManager
                        .contentsOfDirectory(
                            at: crashReportsDir,
                            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                            options: [.skipsHiddenFiles],
                        )
                        .filter { url in
                            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
                                return false
                            }
                            return resourceValues.isRegularFile ?? false
                        }

                    let now = Date()
                    let fiveMinutesAgo = now.addingTimeInterval(-300)

                    for crashFile in crashFiles {
                        if let creationDate = try? crashFile.resourceValues(forKeys: [.creationDateKey]).creationDate,
                           creationDate >= fiveMinutesAgo {
                            Logger.shared.info("找到最近生成的崩溃报告: \(crashFile.lastPathComponent)")
                            return true
                        }
                    }
                } catch {
                    Logger.shared.warning("读取崩溃报告文件夹失败: \(error.localizedDescription)")
                }
            }
            return false
        } catch {
            Logger.shared.error("从数据库查询游戏失败: \(error.localizedDescription)")
            return exitCode != 0
        }
    }

    func collectLogsForGameImmediately(gameId: String) async {
        do {
            try? gameDatabase.initialize()
            guard let game = try gameDatabase.getGame(by: gameId) else {
                Logger.shared.warning("无法从数据库找到游戏: \(gameId)")
                return
            }

            await AppServices.gameLogCollector.collectAndOpenAIWindow(gameName: game.gameName)
        } catch {
            Logger.shared.error("从数据库查询游戏失败: \(error.localizedDescription)")
        }
    }

    private func handleProcessExit(gameId: String, wasManuallyStopped: Bool) {
        if wasManuallyStopped {
            Logger.shared.debug("游戏被用户主动停止: \(gameId)")
        } else {
            Logger.shared.info("游戏进程已退出: \(gameId)")
        }
    }

    func getProcess(for gameId: String, userId: String) -> Process? {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { gameProcesses[key] }
    }

    func stopProcess(for gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let process: Process? = queue.sync {
            guard let proc = gameProcesses[key] else { return nil }
            manuallyStoppedGames.insert(key)
            return proc
        }
        guard let process else { return false }

        if process.isRunning {
            process.terminate()
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
            }
        }

        Logger.shared.debug("停止游戏进程: \(key)")
        return true
    }

    func isGameRunning(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { gameProcesses[key]?.isRunning ?? false }
    }

    func isGameRunningForAnyUser(gameId: String) -> Bool {
        let prefix = "\(gameId)_"
        return queue.sync {
            gameProcesses.contains { key, proc in key.hasPrefix(prefix) && proc.isRunning }
        }
    }

    func cleanupTerminatedProcesses() {
        let terminatedKeys: [String] = queue.sync {
            let keys = gameProcesses.compactMap { key, process in
                !process.isRunning ? key : nil
            }
            guard !keys.isEmpty else { return [] }
            for key in keys {
                gameProcesses.removeValue(forKey: key)
                manuallyStoppedGames.remove(key)
            }
            return keys
        }

        guard !terminatedKeys.isEmpty else { return }

        for key in terminatedKeys {
            Logger.shared.debug("清理已终止的进程: \(key)")
        }

        Task { @MainActor in
            for key in terminatedKeys {
                if let idx = key.firstIndex(of: "_") {
                    let gameId = String(key[..<idx])
                    let userId = String(key[key.index(after: idx)...])
                    AppServices.gameStatusManager.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
                }
            }
        }
    }

    func isManuallyStopped(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { manuallyStoppedGames.contains(key) }
    }

    func removeGameState(gameId: String) {
        let prefix = "\(gameId)_"
        let toRemove: [(String, Process)] = queue.sync {
            let pairs = gameProcesses.filter { key, _ in key.hasPrefix(prefix) }
            for (key, proc) in pairs {
                gameProcesses.removeValue(forKey: key)
                if proc.isRunning {
                    manuallyStoppedGames.insert(key)
                }
            }
            return pairs.map { ($0.key, $0.value) }
        }

        for (key, process) in toRemove where process.isRunning {
            process.terminate()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                process.waitUntilExit()
                self?.queue.async {
                    self?.gameProcesses.removeValue(forKey: key)
                    self?.manuallyStoppedGames.remove(key)
                }
            }
        }

        Task { @MainActor in
            for (key, process) in toRemove where !process.isRunning {
                if let idx = key.firstIndex(of: "_") {
                    let gameId = String(key[..<idx])
                    let userId = String(key[key.index(after: idx)...])
                    AppServices.gameStatusManager.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
                }
            }
        }
    }
}
