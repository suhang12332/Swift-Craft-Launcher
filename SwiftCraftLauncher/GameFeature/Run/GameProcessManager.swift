import Foundation

/// 游戏进程管理器
final class GameProcessManager: ObservableObject, @unchecked Sendable {
    static let shared = GameProcessManager()

    /// 进程存储的 key：gameId + userId 拼接，同一游戏不同玩家分别追踪
    static func processKey(gameId: String, userId: String) -> String {
        "\(gameId)_\(userId)"
    }

    private var gameProcesses: [String: Process] = [:]

    // 标记主动停止的游戏，用于区分用户主动关闭和真正的崩溃
    private var manuallyStoppedGames: Set<String> = []
    private let queue = DispatchQueue(label: "com.swiftcraftlauncher.gameprocessmanager")

    private init() {}

    func storeProcess(gameId: String, userId: String, process: Process) {
        let key = Self.processKey(gameId: gameId, userId: userId)
        // 设置进程终止处理器（在启动前设置）
        // 不在主线程执行：数据库与文件扫描放到后台，仅 UI 状态更新回主线程
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

    // 统一处理所有清理逻辑
    private func handleProcessTermination(gameId: String, userId: String, process: Process) async {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let wasManuallyStopped = queue.sync { manuallyStoppedGames.contains(key) }

        handleProcessExit(gameId: gameId, wasManuallyStopped: wasManuallyStopped)

        if !wasManuallyStopped {
            let isCrash = await checkIfCrash(gameId: gameId, process: process)

            if isCrash {
                let gameSettings = GameSettingsManager.shared
                if gameSettings.enableAICrashAnalysis {
                    Logger.shared.info("检测到游戏崩溃，启用AI分析: \(gameId)")
                    await collectLogsForGameImmediately(gameId: gameId)
                }
            } else {
                Logger.shared.debug("游戏正常退出，不触发AI分析: \(gameId)")
            }
        }

        await MainActor.run {
            GameStatusManager.shared.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
        }
        queue.async { [weak self] in
            self?.gameProcesses.removeValue(forKey: key)
            self?.manuallyStoppedGames.remove(key)
        }
    }

    private func checkIfCrash(gameId: String, process: Process) async -> Bool {
        // 1. 检查退出码：正常退出通常是0，崩溃通常是非0
        // terminate() 停止的进程退出码可能为15，已通过 wasManuallyStopped 排除
        let exitCode = process.terminationStatus
        if exitCode == 0 {
            // 退出码为0，可能是正常退出，但还需要检查是否有崩溃报告
            Logger.shared.debug("游戏退出码为0: \(gameId)")
        } else {
            // 退出码非0，很可能是崩溃
            Logger.shared.info("游戏退出码非0 (\(exitCode))，可能是崩溃: \(gameId)")
            return true
        }

        // 2. 检查是否有崩溃报告文件生成（更准确的判断）
        // 从数据库查询游戏信息以获取游戏名称
        let dbPath = AppPaths.gameVersionDatabase.path
        let database = GameVersionDatabase(dbPath: dbPath)

        do {
            try? database.initialize()
            guard let game = try database.getGame(by: gameId) else {
                Logger.shared.warning("无法从数据库找到游戏，无法检查崩溃报告: \(gameId)")
                // 如果无法查询游戏信息，且退出码非0，则认为是崩溃
                return exitCode != 0
            }

            // 检查崩溃报告文件夹
            let gameDirectory = AppPaths.profileDirectory(gameName: game.gameName)
            let crashReportsDir = gameDirectory.appendingPathComponent(AppConstants.DirectoryNames.crashReports, isDirectory: true)
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: crashReportsDir.path) {
                do {
                    let crashFiles = try fileManager
                        .contentsOfDirectory(
                            at: crashReportsDir,
                            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                            options: [.skipsHiddenFiles]
                        )
                        .filter { url in
                            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
                                return false
                            }
                            return resourceValues.isRegularFile ?? false
                        }

                    // 检查是否有最近生成的崩溃报告（最近5分钟内）
                    let now = Date()
                    let fiveMinutesAgo = now.addingTimeInterval(-300)

                    for crashFile in crashFiles {
                        if let creationDate = try? crashFile.resourceValues(forKeys: [.creationDateKey]).creationDate,
                           creationDate >= fiveMinutesAgo {
                            Logger.shared.info("找到最近生成的崩溃报告: \(crashFile.lastPathComponent)")
                            return true
                        }
                    }

                    // 如果退出码为0但没有最近的崩溃报告，则认为是正常退出
                    // （退出码非0的情况已经在上面处理了）
                } catch {
                    Logger.shared.warning("读取崩溃报告文件夹失败: \(error.localizedDescription)")
                }
            }

            // 如果退出码为0且没有崩溃报告，则认为是正常退出
            return false
        } catch {
            Logger.shared.error("从数据库查询游戏失败: \(error.localizedDescription)")
            // 如果无法查询，且退出码非0，则认为是崩溃
            return exitCode != 0
        }
    }

    /// 为游戏收集日志（可用于基于进程的崩溃检测）
    /// - Parameter gameId: 游戏 ID
    func collectLogsForGameImmediately(gameId: String) async {
        // 从 SQL 数据库查询游戏信息
        let dbPath = AppPaths.gameVersionDatabase.path
        let database = GameVersionDatabase(dbPath: dbPath)

        do {
            // 初始化数据库（如果尚未初始化，可能会失败，可以继续尝试查询）
            try? database.initialize()

            // 从数据库查询游戏
            guard let game = try database.getGame(by: gameId) else {
                Logger.shared.warning("无法从数据库找到游戏: \(gameId)")
                return
            }

            // 创建临时的视图模型和仓库实例用于 AI 窗口
            let playerListViewModel = PlayerListViewModel()
            let gameRepository = GameRepository()

            await GameLogCollector.shared.collectAndOpenAIWindow(
                gameName: game.gameName,
                playerListViewModel: playerListViewModel,
                gameRepository: gameRepository
            )
        } catch {
            Logger.shared.error("从数据库查询游戏失败: \(error.localizedDescription)")
        }
    }

    /// 处理进程退出情况
    private func handleProcessExit(gameId: String, wasManuallyStopped: Bool) {
        if wasManuallyStopped {
            Logger.shared.debug("游戏被用户主动停止: \(gameId)")
        } else {
            Logger.shared.info("游戏进程已退出: \(gameId)")
        }
    }

    /// 获取游戏进程
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - userId: 玩家 ID
    /// - Returns: 进程对象，如果不存在则返回 nil
    func getProcess(for gameId: String, userId: String) -> Process? {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { gameProcesses[key] }
    }

    /// 停止游戏进程（不在主线程等待进程退出，避免卡 UI）
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - userId: 玩家 ID
    /// - Returns: 是否成功发起停止
    func stopProcess(for gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        let process: Process? = queue.sync {
            guard let proc = gameProcesses[key] else { return nil }
            manuallyStoppedGames.insert(key)
            return proc
        }
        guard let process = process else { return false }

        if process.isRunning {
            process.terminate()
            // 在后台等待退出，避免主线程调用 waitUntilExit() 卡住 UI
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
            }
        }

        Logger.shared.debug("停止游戏进程: \(key)")
        return true
    }

    /// 检查指定 gameId+userId 是否正在运行
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - userId: 玩家 ID
    /// - Returns: 是否正在运行
    func isGameRunning(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { gameProcesses[key]?.isRunning ?? false }
    }

    /// 检查该游戏是否有任意玩家的实例正在运行（用于删除前校验）
    /// - Parameter gameId: 游戏 ID
    /// - Returns: 是否有任意 userId 下该游戏在运行
    func isGameRunningForAnyUser(gameId: String) -> Bool {
        let prefix = "\(gameId)_"
        return queue.sync {
            gameProcesses.contains { key, proc in key.hasPrefix(prefix) && proc.isRunning }
        }
    }

    // 清理没有正确触发 terminationHandler 的进程
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
                // key 格式为 "gameId_userId"
                if let idx = key.firstIndex(of: "_") {
                    let gameId = String(key[..<idx])
                    let userId = String(key[key.index(after: idx)...])
                    GameStatusManager.shared.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
                }
            }
        }
    }

    /// 检查游戏是否是被主动停止的
    /// - Parameters:
    ///   - gameId: 游戏 ID
    ///   - userId: 玩家 ID
    /// - Returns: 是否是被主动停止的
    func isManuallyStopped(gameId: String, userId: String) -> Bool {
        let key = Self.processKey(gameId: gameId, userId: userId)
        return queue.sync { manuallyStoppedGames.contains(key) }
    }

    /// 移除指定游戏的所有进程与状态（删除游戏时调用）
    /// 若某 (gameId, userId) 正在运行会先终止进程，在后台等待退出后从内存移除，不阻塞调用线程
    /// - Parameter gameId: 游戏 ID（会移除该 gameId 下所有 userId 的进程）
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
                    GameStatusManager.shared.setGameRunning(gameId: gameId, userId: userId, isRunning: false)
                }
            }
        }
    }
}
