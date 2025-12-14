import Foundation

/// 游戏进程管理器
/// 用于管理游戏进程的启动、停止和状态跟踪
class GameProcessManager: ObservableObject {
    static let shared = GameProcessManager()

    /// 存储游戏进程的字典，key 为游戏 ID
    private var gameProcesses: [String: Process] = [:]

    /// 标记主动停止的游戏，key 为游戏 ID
    /// 用于区分用户主动关闭和真正的崩溃
    private var manuallyStoppedGames: Set<String> = []

    private init() {}

    /// 存储游戏进程并设置终止处理器
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - process: 进程对象
    func storeProcess(gameId: String, process: Process) {
        // 设置进程终止处理器（在启动前设置）
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                await self?.handleProcessTermination(gameId: gameId, process: process)
            }
        }

        gameProcesses[gameId] = process
        Logger.shared.debug("存储游戏进程: \(gameId)")
    }

    /// 处理进程终止事件（统一处理所有清理逻辑）
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - process: 进程对象
    private func handleProcessTermination(gameId: String, process: Process) async {
        // 检查是否检测到了启动错误（在停止监控前检查）
        let hasStartupErrors = GameLaunchErrorDetector.shared.hasDetectedErrors(gameId: gameId)

        // 停止错误监控
        GameLaunchErrorDetector.shared.stopMonitoring(gameId: gameId)

        // 检查是否是被主动停止的（通过启动器停止按钮）
        let wasManuallyStopped = isManuallyStopped(gameId: gameId)

        // 只处理两种情况：启动错误和正常退出
        if hasStartupErrors {
            // 情况1: 检测到启动错误
            handleStartupError(gameId: gameId, wasManuallyStopped: wasManuallyStopped)
        } else {
            // 情况2: 正常退出
            handleNormalExit(gameId: gameId, wasManuallyStopped: wasManuallyStopped)
        }

        // 统一清理：状态更新、进程清理、标记清理、错误状态清理
        GameStatusManager.shared.setGameRunning(gameId: gameId, isRunning: false)
        gameProcesses.removeValue(forKey: gameId)
        manuallyStoppedGames.remove(gameId)
        GameLaunchErrorDetector.shared.cleanupErrorState(gameId: gameId)
    }

    /// 处理启动错误情况
    private func handleStartupError(gameId: String, wasManuallyStopped: Bool) {
        if wasManuallyStopped {
            Logger.shared.info("游戏启动过程中检测到错误，但被用户主动停止: \(gameId)")
        } else {
            Logger.shared.info("游戏启动过程中检测到错误并退出: \(gameId)")
        }
    }

    /// 为游戏收集日志（在检测到错误时调用）
    /// - Parameter gameId: 游戏 ID
    func collectLogsForGameImmediately(gameId: String) async {
        // 从 UserDefaults 中加载游戏列表来查找游戏名称
        guard let savedGamesData = UserDefaults.standard.data(forKey: "savedGames") else {
            return
        }

        guard let games = try? JSONDecoder().decode([GameVersionInfo].self, from: savedGamesData),
              let game = games.first(where: { $0.id == gameId }) else {
            return
        }

        await GameLogCollector.shared.collectAndOpenAIWindow(gameName: game.gameName)
    }

    /// 处理正常退出情况
    private func handleNormalExit(gameId: String, wasManuallyStopped: Bool) {
        if wasManuallyStopped {
            Logger.shared.debug("游戏被用户主动停止: \(gameId)")
        } else {
            Logger.shared.debug("游戏正常退出: \(gameId)")
        }
    }

    /// 获取游戏进程
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 进程对象，如果不存在则返回 nil
    func getProcess(for gameId: String) -> Process? {
        return gameProcesses[gameId]
    }

    /// 停止游戏进程
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 是否成功停止
    func stopProcess(for gameId: String) -> Bool {
        guard let process = gameProcesses[gameId] else {
            return false
        }

        // 标记为主动停止，避免被判定为崩溃
        manuallyStoppedGames.insert(gameId)

        if process.isRunning {
            process.terminate()
            // 等待进程终止
            process.waitUntilExit()
        }

        // 注意：不在这里移除进程，让 terminationHandler 统一处理清理
        // terminationHandler 会自动处理错误监控停止、状态更新和进程清理

        // 延迟清理标记，确保 terminationHandler 能够正确读取标记
        // terminationHandler 是异步执行的，可能在 waitUntilExit() 返回后才执行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.manuallyStoppedGames.remove(gameId)
        }

        Logger.shared.debug("停止游戏进程: \(gameId)")
        return true
    }

    /// 检查游戏是否正在运行
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 是否正在运行
    func isGameRunning(gameId: String) -> Bool {
        guard let process = gameProcesses[gameId] else {
            return false
        }
        return process.isRunning
    }

    /// 清理已终止的进程
    /// 注意：这个方法主要用于清理那些没有正确触发 terminationHandler 的进程
    /// 正常情况下，进程终止应该通过 terminationHandler 处理
    func cleanupTerminatedProcesses() {
        let terminatedGameIds = gameProcesses.compactMap { gameId, process in
            !process.isRunning ? gameId : nil
        }

        // 如果没有需要清理的进程，直接返回
        guard !terminatedGameIds.isEmpty else {
            return
        }

        for gameId in terminatedGameIds {
            // 停止错误监控（如果还在运行）
            GameLaunchErrorDetector.shared.stopMonitoring(gameId: gameId)
            // 清理进程
            gameProcesses.removeValue(forKey: gameId)
            // 清理手动停止标记
            manuallyStoppedGames.remove(gameId)
        }

        DispatchQueue.main.async {
            for gameId in terminatedGameIds {
                Logger.shared.debug("清理已终止的进程: \(gameId)")
            }
        }

        // 通知状态管理器更新状态
        Task { @MainActor in
            for gameId in terminatedGameIds {
                GameStatusManager.shared.setGameRunning(gameId: gameId, isRunning: false)
                // 清理错误检测器的状态
                GameLaunchErrorDetector.shared.cleanupErrorState(gameId: gameId)
            }
        }
    }

    /// 检查游戏是否是被主动停止的
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 是否是被主动停止的
    func isManuallyStopped(gameId: String) -> Bool {
        return manuallyStoppedGames.contains(gameId)
    }
}
