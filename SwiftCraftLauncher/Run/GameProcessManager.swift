import Foundation

/// 游戏进程管理器
/// 用于管理游戏进程的启动、停止和状态跟踪
class GameProcessManager: ObservableObject {
    static let shared = GameProcessManager()

    /// 存储游戏进程的字典，key 为游戏 ID
    private var gameProcesses: [String: Process] = [:]

    private init() {}

    /// 存储游戏进程
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - process: 进程对象
    func storeProcess(gameId: String, process: Process) {
        gameProcesses[gameId] = process
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
        gameProcesses = gameProcesses.filter { _, process in
            process.isRunning
        }
    }
}
