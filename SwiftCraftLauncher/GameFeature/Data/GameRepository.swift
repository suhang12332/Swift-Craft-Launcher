import Combine
import Foundation

/// 游戏版本信息仓库
class GameRepository: ObservableObject {
    // MARK: - Properties

    /// 按工作路径分组的游戏列表，键为工作路径，值为游戏数组
    @Published private(set) var gamesByWorkingPath: [String: [GameVersionInfo]] = [:]

    var games: [GameVersionInfo] {
        gamesByWorkingPath[currentWorkingPath] ?? []
    }

    private var currentWorkingPath: String {
        workingPathProvider.currentWorkingPath
    }

    private let workingPathProvider: WorkingPathProviding
    private let database: GameVersionDatabase
    private var workingPathCancellable: AnyCancellable?
    private var lastWorkingPath: String = ""

    @Published var workingPathChanged: Bool = false

    // MARK: - Initialization

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

        DispatchQueue.main.async { [weak self] in
            self?.setupWorkingPathObserver()
        }
    }

    /// 初始化数据库
    private func initializeDatabase() async throws {
        // 创建数据库目录
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

    func addGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let dbPath = AppPaths.gameVersionDatabase.path
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            let db = GameVersionDatabase(dbPath: dbPath)
            try? db.initialize()
            try db.saveGame(gameToSave, workingPath: workingPath)
        }.value

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

    func addGameSilently(_ game: GameVersionInfo) {
        Task {
            do {
                try await addGame(game)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
    }

    func deleteGame(id: String) async throws {
        let workingPath = currentWorkingPath
        guard let game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要删除的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_delete",
                level: .notification
            )
        }
        let dbPath = AppPaths.gameVersionDatabase.path

        try await Task.detached(priority: .userInitiated) {
            let db = GameVersionDatabase(dbPath: dbPath)
            try? db.initialize()
            try db.deleteGame(id: id)
        }.value

        await MainActor.run {
            gamesByWorkingPath[workingPath]?.removeAll { $0.id == id }
        }

        Logger.shared.info("成功删除游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    func deleteGameSilently(id: String) {
        Task {
            do {
                try await deleteGame(id: id)
            } catch {
                GlobalErrorHandler.shared.handle(error)
            }
        }
    }

    func getGame(by id: String) -> GameVersionInfo? {
        return games.first { $0.id == id }
    }

    func getGameByName(by gameName: String) -> GameVersionInfo? {
        return games.first { $0.gameName == gameName }
    }

    func updateGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let dbPath = AppPaths.gameVersionDatabase.path
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            let db = GameVersionDatabase(dbPath: dbPath)
            try? db.initialize()
            try db.saveGame(gameToSave, workingPath: workingPath)
        }.value

        await MainActor.run {
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == game.id }) {
                gamesByWorkingPath[workingPath]?[index] = game
            } else {
                if gamesByWorkingPath[workingPath] == nil {
                    gamesByWorkingPath[workingPath] = []
                }
                gamesByWorkingPath[workingPath]?.append(game)
            }
        }

        Logger.shared.info("成功更新游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

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

    func updateGameLastPlayed(id: String, lastPlayed: Date = Date()) async throws {
        let workingPath = currentWorkingPath
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新状态的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_status",
                level: .notification
            )
        }
        let dbPath = AppPaths.gameVersionDatabase.path

        try await Task.detached(priority: .userInitiated) {
            let db = GameVersionDatabase(dbPath: dbPath)
            try? db.initialize()
            try db.updateLastPlayed(id: id, lastPlayed: lastPlayed)
        }.value

        game.lastPlayed = lastPlayed
        let updatedGame = game
        await MainActor.run {
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == id }) {
                gamesByWorkingPath[workingPath]?[index] = updatedGame
            }
        }

        Logger.shared.info("成功更新游戏最后游玩时间: \(game.gameName) (工作路径: \(workingPath))")
    }

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

    // 异步扫描所有游戏的 mods 目录
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

    /// 获取数据库中所有工作路径及其游戏数量（用于设置页快速切换，SQL GROUP BY 实现）
    func fetchAllWorkingPathsWithCounts() async -> [(path: String, count: Int)] {
        let currentPath = currentWorkingPath
        let dbPath = AppPaths.gameVersionDatabase.path
        let rows: [(path: String, count: Int)]
        do {
            rows = try await Task.detached(priority: .userInitiated) {
                let db = GameVersionDatabase(dbPath: dbPath)
                try? db.initialize()
                return try db.loadWorkingPathsWithCounts()
            }.value
        } catch {
            return [(currentPath, 0)]
        }
        var result = rows
        if !result.contains(where: { $0.path == currentPath }) {
            result.append((currentPath, 0))
        }
        result.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return result
    }

    // 只加载当前工作路径的游戏（数据库与目录扫描在后台执行，避免主线程阻塞）
    func loadGamesThrowing() async throws {
        let workingPath = currentWorkingPath
        let dbPath = AppPaths.gameVersionDatabase.path

        let (validGames, pathForLog): ([GameVersionInfo], String) = try await Task.detached(priority: .userInitiated) {
            let db = GameVersionDatabase(dbPath: dbPath)
            try? db.initialize()
            let games = try db.loadGames(workingPath: workingPath)
            let fm = FileManager.default
            let baseURL = URL(fileURLWithPath: workingPath, isDirectory: true)
            let profileRootDir = baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
            let localGameNames: Set<String>
            do {
                if fm.fileExists(atPath: profileRootDir.path) {
                    let contents = try fm.contentsOfDirectory(atPath: profileRootDir.path)
                    localGameNames = Set(contents)
                } else {
                    localGameNames = []
                }
            } catch {
                Logger.shared.warning("无法读取工作路径的游戏目录: \(workingPath), 错误: \(error.localizedDescription)")
                localGameNames = []
            }
            let valid = games.filter { localGameNames.contains($0.gameName) }
            return (valid, workingPath)
        }.value

        await MainActor.run {
            gamesByWorkingPath = [workingPath: validGames]
        }

        Logger.shared.info("成功加载 \(validGames.count) 个游戏（工作路径: \(pathForLog)）")
    }
}
