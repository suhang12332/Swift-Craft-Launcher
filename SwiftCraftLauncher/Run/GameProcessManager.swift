import Foundation

/// 游戏进程管理器
/// 用于管理游戏进程的启动、停止和状态跟踪
class GameProcessManager: ObservableObject {
    static let shared = GameProcessManager()

    /// 存储游戏进程的字典，key 为游戏 ID
    private var gameProcesses: [String: Process] = [:]

    /// 进程状态变化通知
    @Published var processStates: [String: Bool] = [:]

    private init() {}

    /// 存储游戏进程
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - process: 进程对象
    func storeProcess(gameId: String, process: Process) {
        gameProcesses[gameId] = process
        processStates[gameId] = true
        Logger.shared.debug("存储游戏进程: \(gameId)")
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

        if process.isRunning {
            process.terminate()
            // 等待进程终止
            process.waitUntilExit()
        }

        gameProcesses.removeValue(forKey: gameId)
        processStates[gameId] = false
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
    func cleanupTerminatedProcesses() {
        let terminatedGameIds = gameProcesses.compactMap { gameId, process in
            !process.isRunning ? gameId : nil
        }

        // 如果没有需要清理的进程，直接返回
        guard !terminatedGameIds.isEmpty else {
            return
        }

        for gameId in terminatedGameIds {
            gameProcesses.removeValue(forKey: gameId)
            processStates[gameId] = false
            Logger.shared.debug("清理已终止的进程: \(gameId)")
        }

        // 通知状态管理器更新状态
        Task { @MainActor in
            for gameId in terminatedGameIds {
                GameStatusManager.shared.setGameRunning(gameId: gameId, isRunning: false)
            }
        }
    }

    /// 清理特定游戏的进程
    /// - Parameter gameId: 游戏ID
    func cleanupSpecificProcess(gameId: String) {
        guard let process = gameProcesses[gameId] else {
            return
        }

        // 检查进程是否已经终止
        if !process.isRunning {
            gameProcesses.removeValue(forKey: gameId)
            processStates[gameId] = false
            Logger.shared.debug("清理特定进程: \(gameId)")
        }
    }
}
