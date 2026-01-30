import Combine
import Foundation

/// 游戏版本信息仓库
/// 负责游戏版本信息的持久化存储和管理
/// 使用 SQLite (WAL + mmap + JSON1) 进行存储
class GameRepository: ObservableObject {
    // MARK: - Properties

    /// 按工作路径分组的游戏列表
    /// 键为工作路径，值为该路径下的游戏数组
    @Published private(set) var gamesByWorkingPath: [String: [GameVersionInfo]] = [:]

    /// 当前工作路径下的游戏列表（计算属性）
    var games: [GameVersionInfo] {
        gamesByWorkingPath[currentWorkingPath] ?? []
    }

    /// 获取当前工作路径（由注入的 WorkingPathProviding 提供，职责分离）
    private var currentWorkingPath: String {
        workingPathProvider.currentWorkingPath
    }

    /// 工作路径提供者（协议注入，不直接依赖 GeneralSettingsManager）
    private let workingPathProvider: WorkingPathProviding

    /// SQLite 数据库存储层
    private let database: GameVersionDatabase

    /// 工作路径变化订阅者
    private var workingPathCancellable: AnyCancellable?

    /// 上次记录的工作路径，用于检测变化
    private var lastWorkingPath: String = ""

    /// 工作路径改变通知（用于触发UI切换）
    @Published var workingPathChanged: Bool = false

    // MARK: - Initialization

    /// - Parameter workingPathProvider: 工作路径提供者，默认使用 GeneralSettingsManager.shared
    init(workingPathProvider: WorkingPathProviding = GeneralSettingsManager.shared) {
        self.workingPathProvider = workingPathProvider
        let dbPath = AppPaths.gameVersionDatabase.path
        self.database = GameVersionDatabase(dbPath: dbPath)

        lastWorkingPath = currentWorkingPath

        // 初始化数据库
        Task {
            do {
                try await initializeDatabase()
                loadGamesSafely()
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }

        // 延迟设置观察者，避免在初始化时立即触发
        DispatchQueue.main.async { [weak self] in
            self?.setupWorkingPathObserver()
        }
    }

    /// 初始化数据库
    private func initializeDatabase() async throws {
        // 确保数据库目录存在
        let dataDir = AppPaths.dataDirectory
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // 初始化数据库
        try database.initialize()
    }

    deinit {
        workingPathCancellable?.cancel()
    }

    /// 设置工作路径变化观察者
    private func setupWorkingPathObserver() {
        // 在设置观察者之前，先同步更新 lastWorkingPath，避免初始化时的误触发
        lastWorkingPath = currentWorkingPath

        // 使用注入的 WorkingPathProviding 监听工作路径变化
        // 使用 debounce 避免频繁触发
        // 使用 skip(1) 跳过订阅时的初始值，只响应后续的变化
        workingPathCancellable = workingPathProvider.workingPathWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 检查工作路径是否真的改变了
                let newPath = self.currentWorkingPath
                if newPath != self.lastWorkingPath {
                    self.lastWorkingPath = newPath
                    // 通知工作路径已改变（用于触发UI切换）
                    self.workingPathChanged = true
                    // 当工作路径改变时，重新加载当前工作路径的游戏
                    Task { @MainActor in
                        do {
                            try await self.loadGamesThrowing()
                            // 重置通知标志
                            self.workingPathChanged = false
                        } catch {
                            GlobalErrorHandler.shared.handle(error)
                            // 即使出错也要重置标志
                            self.workingPathChanged = false
                        }
                    }
                }
            }
    }

    // MARK: - Public Methods

    /// 添加新游戏
    /// - Parameter game: 要添加的游戏版本信息
    /// - Throws: GlobalError 当操作失败时
    func addGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath

        // 保存到数据库
        try database.saveGame(game, workingPath: workingPath)

        // 更新内存缓存
        await MainActor.run {
            if gamesByWorkingPath[workingPath] == nil {
                gamesByWorkingPath[workingPath] = []
            }
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == game.id }) {
                gamesByWorkingPath[workingPath]?[index] = game
            } else {
                gamesByWorkingPath[workingPath]?.append(game)
            }
        }

        Logger.shared.info("成功添加游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    /// 添加新游戏（静默版本）
    /// - Parameter game: 要添加的游戏版本信息
    func addGameSilently(_ game: GameVersionInfo) {
        Task {
            do {
                try await addGame(game)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
    }

    /// 删除游戏
    /// - Parameter id: 要删除的游戏ID
    /// - Throws: GlobalError 当操作失败时
    func deleteGame(id: String) async throws {
        let workingPath = currentWorkingPath
        guard let game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要删除的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_delete",
                level: .notification
            )
        }

        // 从数据库删除
        try database.deleteGame(id: id)

        // 更新内存缓存
        await MainActor.run {
            gamesByWorkingPath[workingPath]?.removeAll { $0.id == id }
        }

        Logger.shared.info("成功删除游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    /// 删除游戏（静默版本）
    /// - Parameter id: 要删除的游戏ID
    func deleteGameSilently(id: String) {
        Task {
            do {
                try await deleteGame(id: id)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
    }

    /// 根据游戏ID查找游戏版本信息
    /// - Parameter id: 游戏ID
    /// - Returns: 匹配的 GameVersionInfo 对象，如果找不到则返回 nil
    func getGame(by id: String) -> GameVersionInfo? {
        return games.first { $0.id == id }
    }

    /// 根据游戏名称查找游戏版本信息
    /// - Parameter gameName: 游戏名称
    /// - Returns: 匹配的 GameVersionInfo 对象，如果找不到则返回 nil
    func getGameByName(by gameName: String) -> GameVersionInfo? {
        return games.first { $0.gameName == gameName }
    }

    /// 根据 ID 更新游戏信息
    /// - Parameter game: 新的游戏信息
    /// - Throws: GlobalError 当操作失败时
    func updateGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath

        // 保存到数据库
        try database.saveGame(game, workingPath: workingPath)

        // 更新内存缓存
        await MainActor.run {
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == game.id }) {
                gamesByWorkingPath[workingPath]?[index] = game
            } else {
                // 如果内存中没有，添加到内存
                if gamesByWorkingPath[workingPath] == nil {
                    gamesByWorkingPath[workingPath] = []
                }
                gamesByWorkingPath[workingPath]?.append(game)
            }
        }

        Logger.shared.info("成功更新游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    /// 根据 ID 更新游戏信息（静默版本）
    /// - Parameter game: 新的游戏信息
    /// - Returns: 是否更新成功
    func updateGameSilently(_ game: GameVersionInfo) -> Bool {
        Task {
            do {
                try await updateGame(game)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
        return true // Note: This will always return true since the operation is async
    }

    /// 根据 ID 更新游戏最后游玩时间
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - lastPlayed: 最后游玩时间
    /// - Throws: GlobalError 当操作失败时
    func updateGameLastPlayed(id: String, lastPlayed: Date = Date()) async throws {
        let workingPath = currentWorkingPath
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新状态的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_status",
                level: .notification
            )
        }

        // 更新数据库
        try database.updateLastPlayed(id: id, lastPlayed: lastPlayed)

        // 更新内存缓存
        game.lastPlayed = lastPlayed
        let updatedGame = game
        await MainActor.run {
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == id }) {
                gamesByWorkingPath[workingPath]?[index] = updatedGame
            }
        }

        Logger.shared.info("成功更新游戏最后游玩时间: \(game.gameName) (工作路径: \(workingPath))")
    }

    /// 根据 ID 更新游戏最后游玩时间（静默版本）
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - lastPlayed: 最后游玩时间
    /// - Returns: 是否更新成功
    func updateGameLastPlayedSilently(id: String, lastPlayed: Date = Date()) -> Bool {
        Task {
            do {
                try await updateGameLastPlayed(id: id, lastPlayed: lastPlayed)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
        return true // Note: This will always return true since the operation is async
    }

    /// 更新 Java 路径
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - javaPath: 新的 Java 路径
    /// - Throws: GlobalError 当操作失败时
    func updateJavaPath(id: String, javaPath: String) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 Java 路径的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_java",
                level: .notification
            )
        }

        game.javaPath = javaPath
        try await updateGame(game)
        Logger.shared.info("成功更新游戏 Java 路径: \(game.gameName)")
    }

    /// 更新 Java 路径（静默版本）
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - javaPath: 新的 Java 路径
    /// - Returns: 是否更新成功
    func updateJavaPathSilently(id: String, javaPath: String) -> Bool {
        Task {
            do {
                try await updateJavaPath(id: id, javaPath: javaPath)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
        return true // Note: This will always return true since the operation is async
    }

    /// 更新 JVM 启动参数
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - jvmArguments: 新的 JVM 参数
    /// - Throws: GlobalError 当操作失败时
    func updateJvmArguments(id: String, jvmArguments: String) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 JVM 参数的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_jvm",
                level: .notification
            )
        }

        game.jvmArguments = jvmArguments
        try await updateGame(game)
        Logger.shared.info("成功更新游戏 JVM 参数: \(game.gameName)")
    }

    /// 更新 JVM 启动参数（静默版本）
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - jvmArguments: 新的 JVM 参数
    /// - Returns: 是否更新成功
    func updateJvmArgumentsSilently(id: String, jvmArguments: String) -> Bool {
        Task {
            do {
                try await updateJvmArguments(id: id, jvmArguments: jvmArguments)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
        return true // Note: This will always return true since the operation is async
    }

    /// 更新运行内存大小
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - xms: 新的 xms 内存大小（MB）
    ///   - xmx: 新的 xmx 内存大小（MB）
    /// - Throws: GlobalError 当操作失败时
    func updateMemorySize(id: String, xms: Int, xmx: Int) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新内存大小的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_memory",
                level: .notification
            )
        }

        // 验证内存参数
        guard xms > 0 && xmx > 0 && xms <= xmx else {
            throw GlobalError.validation(
                chineseMessage: "无效的内存参数：xms=\(xms), xmx=\(xmx)",
                i18nKey: "error.validation.invalid_memory_params",
                level: .notification
            )
        }

        game.xms = xms
        game.xmx = xmx
        try await updateGame(game)
        Logger.shared.info("成功更新游戏内存大小: \(game.gameName)")
    }

    /// 更新运行内存大小（静默版本）
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - xms: 新的 xms 内存大小（MB）
    ///   - xmx: 新的 xmx 内存大小（MB）
    /// - Returns: 是否更新成功
    func updateMemorySizeSilently(id: String, xms: Int, xmx: Int) -> Bool {
        Task {
            do {
                try await updateMemorySize(id: id, xms: xms, xmx: xmx)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
        return true // Note: This will always return true since the operation is async
    }

    // MARK: - Private Methods

    /// 从 UserDefaults 加载游戏列表（静默版本）
    func loadGames() {
        loadGamesSafely()
    }

    /// 从 UserDefaults 加载游戏列表（静默版本）
    private func loadGamesSafely() {
        Task {
            do {
                try await loadGamesThrowing()

                // 加载完成后，扫描所有游戏的 mods 目录
                await scanAllGamesModsDirectory()
            } catch {
                GlobalErrorHandler.shared.handle(error)
                await MainActor.run {
                    gamesByWorkingPath = [:]
                }
            }
        }
    }

    /// 扫描所有游戏的 mods 目录
    /// 异步执行，不会阻塞 UI
    private func scanAllGamesModsDirectory() async {
        let games = games
        Logger.shared.info("开始扫描 \(games.count) 个游戏的 mods 目录")

        // 并发扫描所有游戏
        await withTaskGroup(of: Void.self) { group in
            for game in games {
                group.addTask {
                    await ModScanner.shared.scanGameModsDirectory(game: game)
                }
            }
        }

        Logger.shared.info("完成所有游戏的 mods 目录扫描")
    }

    /// 从 SQLite 加载游戏列表（抛出异常版本）
    /// 只加载当前工作路径的游戏，其他工作路径的数据不会被加载到内存中
    /// - Throws: GlobalError 当操作失败时
    func loadGamesThrowing() async throws {
        let workingPath = currentWorkingPath

        // 从数据库加载当前工作路径的游戏
        let games = try database.loadGames(workingPath: workingPath)

        // 验证当前工作路径下的游戏，只保留实际存在的游戏
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: workingPath, isDirectory: true)
        let profileRootDir = baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)

        let localGameNames: Set<String>
        do {
            if fileManager.fileExists(atPath: profileRootDir.path) {
                let contents = try fileManager.contentsOfDirectory(atPath: profileRootDir.path)
                localGameNames = Set(contents)
            } else {
                localGameNames = []
            }
        } catch {
            Logger.shared.warning("无法读取工作路径的游戏目录: \(workingPath), 错误: \(error.localizedDescription)")
            localGameNames = []
        }

        // 只保留在当前工作路径下实际存在的游戏
        let validGames = games.filter { localGameNames.contains($0.gameName) }

        await MainActor.run {
            // 只保存当前工作路径的游戏到内存中，其他路径的数据不加载
            gamesByWorkingPath = [workingPath: validGames]
        }

        Logger.shared.info("成功加载 \(validGames.count) 个游戏（工作路径: \(workingPath)）")
    }
}
