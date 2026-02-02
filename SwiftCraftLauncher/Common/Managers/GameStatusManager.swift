import Foundation

/// 游戏状态管理器
/// 基于实际进程状态管理游戏运行状态，使用gameId作为key
class GameStatusManager: ObservableObject {
    static let shared = GameStatusManager()
    /// 游戏运行状态字典，key为gameId，value为是否正在运行
    @Published private var gameRunningStates: [String: Bool] = [:]
    /// 游戏启动中状态字典，key为gameId，value为是否正在启动（尚未进入运行态）
    @Published private var gameLaunchingStates: [String: Bool] = [:]

    private init() {}

    /// 检查指定游戏是否正在运行
    /// - Parameter gameId: 游戏ID
    /// - Returns: 是否正在运行
    func isGameRunning(gameId: String) -> Bool {
        let actuallyRunning = GameProcessManager.shared.isGameRunning(gameId: gameId)

        DispatchQueue.main.async {
            self.updateGameStatusIfNeeded(gameId: gameId, actuallyRunning: actuallyRunning)
        }

        return actuallyRunning
    }
    /// 更新游戏状态（如果需要）
    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - actuallyRunning: 实际运行状态
    private func updateGameStatusIfNeeded(gameId: String, actuallyRunning: Bool) {
        if let cachedState = gameRunningStates[gameId], cachedState != actuallyRunning {
            gameRunningStates[gameId] = actuallyRunning
            Logger.shared.debug("游戏状态同步更新: \(gameId) -> \(actuallyRunning ? "运行中" : "已停止")")
        } else if gameRunningStates[gameId] == nil {
            gameRunningStates[gameId] = actuallyRunning
        }
    }

    /// 强制刷新指定游戏的状态
    /// - Parameter gameId: 游戏ID
    func refreshGameStatus(gameId: String) {
        let actuallyRunning = GameProcessManager.shared.isGameRunning(gameId: gameId)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameRunningStates[gameId] = actuallyRunning
            Logger.shared.debug("强制刷新游戏状态: \(gameId) -> \(actuallyRunning ? "运行中" : "已停止")")
        }
    }

    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - isRunning: 是否正在运行
    func setGameRunning(gameId: String, isRunning: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentState = self.gameRunningStates[gameId]
            if currentState != isRunning {
                self.gameRunningStates[gameId] = isRunning
                Logger.shared.debug("游戏状态更新: \(gameId) -> \(isRunning ? "运行中" : "已停止")")
            }
        }
    }

    /// 清理已停止的游戏状态
    func cleanupStoppedGames() {
        let processManager = GameProcessManager.shared

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameRunningStates = self.gameRunningStates.filter { gameId, _ in
                processManager.isGameRunning(gameId: gameId)
            }
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

    // MARK: - 启动中状态管理

    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - isLaunching: 是否正在启动
    func setGameLaunching(gameId: String, isLaunching: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentState = self.gameLaunchingStates[gameId] ?? false
            if currentState != isLaunching {
                self.gameLaunchingStates[gameId] = isLaunching
                Logger.shared.debug("游戏启动中状态更新: \(gameId) -> \(isLaunching ? "启动中" : "非启动中")")
            }
        }
    }

    /// - Parameter gameId: 游戏ID
    /// - Returns: 是否正在启动
    func isGameLaunching(gameId: String) -> Bool {
        return gameLaunchingStates[gameId] ?? false
    }

    /// - Parameter gameId: 游戏ID
    func removeGameState(gameId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameRunningStates.removeValue(forKey: gameId)
            self.gameLaunchingStates.removeValue(forKey: gameId)
        }
    }
}
