import Foundation

/// 游戏状态管理器
/// 基于实际进程状态管理游戏运行状态，使用gameId作为key
class GameStatusManager: ObservableObject {
    static let shared = GameStatusManager()
    /// 游戏运行状态字典，key为gameId，value为是否正在运行
    @Published private var gameRunningStates: [String: Bool] = [:]

    private init() {
        // 移除定期检测，改为按需检查
    }

    /// 检查指定游戏是否正在运行
    /// - Parameter gameId: 游戏ID
    /// - Returns: 是否正在运行
    func isGameRunning(gameId: String) -> Bool {
        // 按需检查：如果缓存显示游戏在运行，验证进程是否真的在运行
        if let cachedState = gameRunningStates[gameId] {
            if cachedState {
                let actuallyRunning = GameProcessManager.shared.isGameRunning(gameId: gameId)
                if !actuallyRunning {
                    // 进程已终止，更新缓存状态
                    gameRunningStates[gameId] = false
                    Logger.shared.debug("游戏状态按需更新: \(gameId) -> 已停止")
                }
                return actuallyRunning
            }
            return false
        }
        return false
    }

    /// 设置游戏运行状态
    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - isRunning: 是否正在运行
    func setGameRunning(gameId: String, isRunning: Bool) {
        gameRunningStates[gameId] = isRunning
        Logger.shared.debug("游戏状态更新: \(gameId) -> \(isRunning ? "运行中" : "已停止")")
    }

    /// 清理已停止的游戏状态
    func cleanupStoppedGames() {
        let processManager = GameProcessManager.shared

        gameRunningStates = gameRunningStates.filter { gameId, _ in
            processManager.isGameRunning(gameId: gameId)
        }
    }

    /// 获取所有正在运行的游戏ID
    var runningGameIds: [String] {
        return gameRunningStates.compactMap { gameId, isRunning in
            isRunning ? gameId : nil
        }
    }

    /// 获取所有游戏状态
    var allGameStates: [String: Bool] {
        return gameRunningStates
    }
}
