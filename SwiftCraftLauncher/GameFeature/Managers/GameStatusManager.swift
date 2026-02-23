import Foundation

/// 游戏状态管理器
/// 基于实际进程状态管理游戏运行状态，key 为 gameId_userId 拼接，同一游戏不同玩家分别追踪
class GameStatusManager: ObservableObject {
    static let shared = GameStatusManager()
    /// 游戏运行状态字典，key 为 processKey(gameId, userId)，value 为是否正在运行
    @Published private var gameRunningStates: [String: Bool] = [:]
    /// 游戏启动中状态字典，key 为 processKey(gameId, userId)，value 为是否正在启动（尚未进入运行态）
    @Published private var gameLaunchingStates: [String: Bool] = [:]

    private init() {}

    /// 检查指定 gameId+userId 是否正在运行
    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - userId: 玩家ID
    /// - Returns: 是否正在运行
    func isGameRunning(gameId: String, userId: String) -> Bool {
        let actuallyRunning = GameProcessManager.shared.isGameRunning(gameId: gameId, userId: userId)
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)

        DispatchQueue.main.async {
            self.updateGameStatusIfNeeded(key: key, actuallyRunning: actuallyRunning)
        }

        return actuallyRunning
    }

    /// 更新游戏状态（如果需要）
    /// - Parameters:
    ///   - key: processKey(gameId, userId)
    ///   - actuallyRunning: 实际运行状态
    private func updateGameStatusIfNeeded(key: String, actuallyRunning: Bool) {
        if let cachedState = gameRunningStates[key], cachedState != actuallyRunning {
            gameRunningStates[key] = actuallyRunning
            Logger.shared.debug("游戏状态同步更新: \(key) -> \(actuallyRunning ? "运行中" : "已停止")")
        } else if gameRunningStates[key] == nil {
            gameRunningStates[key] = actuallyRunning
        }
    }

    /// 强制刷新指定 (gameId, userId) 的状态
    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - userId: 玩家ID
    func refreshGameStatus(gameId: String, userId: String) {
        let actuallyRunning = GameProcessManager.shared.isGameRunning(gameId: gameId, userId: userId)
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameRunningStates[key] = actuallyRunning
            Logger.shared.debug("强制刷新游戏状态: \(key) -> \(actuallyRunning ? "运行中" : "已停止")")
        }
    }

    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - userId: 玩家ID
    ///   - isRunning: 是否正在运行
    func setGameRunning(gameId: String, userId: String, isRunning: Bool) {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentState = self.gameRunningStates[key]
            if currentState != isRunning {
                self.gameRunningStates[key] = isRunning
                Logger.shared.debug("游戏状态更新: \(key) -> \(isRunning ? "运行中" : "已停止")")
            }
        }
    }

    /// 清理已停止的游戏状态
    func cleanupStoppedGames() {
        let processManager = GameProcessManager.shared

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameRunningStates = self.gameRunningStates.filter { key, isRunning in
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

    /// 获取所有正在运行的 processKey 列表
    var runningProcessKeys: [String] {
        gameRunningStates.compactMap { key, isRunning in
            isRunning ? key : nil
        }
    }

    /// 获取所有游戏状态（key 为 processKey）
    var allGameStates: [String: Bool] {
        return gameRunningStates
    }

    // MARK: - 启动中状态管理

    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - userId: 玩家ID
    ///   - isLaunching: 是否正在启动
    func setGameLaunching(gameId: String, userId: String, isLaunching: Bool) {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentState = self.gameLaunchingStates[key] ?? false
            if currentState != isLaunching {
                self.gameLaunchingStates[key] = isLaunching
                Logger.shared.debug("游戏启动中状态更新: \(key) -> \(isLaunching ? "启动中" : "非启动中")")
            }
        }
    }

    /// - Parameters:
    ///   - gameId: 游戏ID
    ///   - userId: 玩家ID
    /// - Returns: 是否正在启动
    func isGameLaunching(gameId: String, userId: String) -> Bool {
        let key = GameProcessManager.processKey(gameId: gameId, userId: userId)
        return gameLaunchingStates[key] ?? false
    }

    /// 移除指定 gameId 下所有 userId 的状态（删除游戏时调用）
    /// - Parameter gameId: 游戏ID
    func removeGameState(gameId: String) {
        let prefix = "\(gameId)_"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let keysToRemove = self.gameRunningStates.keys.filter { $0.hasPrefix(prefix) }
                + self.gameLaunchingStates.keys.filter { $0.hasPrefix(prefix) }
            for key in keysToRemove {
                self.gameRunningStates.removeValue(forKey: key)
                self.gameLaunchingStates.removeValue(forKey: key)
            }
        }
    }
}
