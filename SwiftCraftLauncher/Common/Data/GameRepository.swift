import Combine
import Foundation

/// 游戏版本信息仓库
/// 负责游戏版本信息的持久化存储和管理
class GameRepository: ObservableObject {
    // MARK: - Properties

    /// 已保存的游戏列表
    @Published private(set) var games: [GameVersionInfo] = []

    /// UserDefaults 存储键
    private let gamesKey = "savedGames"

    // MARK: - Initialization

    init() {
        loadGamesSafely()
    }

    // MARK: - Public Methods

    /// 添加新游戏
    /// - Parameter game: 要添加的游戏版本信息
    /// - Throws: GlobalError 当操作失败时
    func addGame(_ game: GameVersionInfo) async throws {
        await MainActor.run {
            games.append(game)
        }
        try saveGamesThrowing()
        Logger.shared.info("成功添加游戏: \(game.gameName)")
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
        guard let game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要删除的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_delete",
                level: .notification
            )
        }
        
        await MainActor.run {
            games.removeAll { $0.id == id }
        }
        try saveGamesThrowing()
        Logger.shared.info("成功删除游戏: \(game.gameName)")
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
        guard let index = games.firstIndex(where: { $0.id == game.id }) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新的游戏：\(game.id)",
                i18nKey: "error.validation.game_not_found_update",
                level: .notification
            )
        }
        
        await MainActor.run {
            games[index] = game
        }
        try saveGamesThrowing()
        Logger.shared.info("成功更新游戏: \(game.gameName)")
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
    
    /// 根据 ID 更新游戏状态
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - isRunning: 是否正在运行
    ///   - lastPlayed: 最后游玩时间
    /// - Throws: GlobalError 当操作失败时
    func updateGameStatus(id: String, isRunning: Bool, lastPlayed: Date = Date()) async throws {
        guard let index = games.firstIndex(where: { $0.id == id }) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新状态的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_status",
                level: .notification
            )
        }
        
        await MainActor.run {
            var game = games[index]
            game.isRunning = isRunning
            game.lastPlayed = lastPlayed
            games[index] = game
        }
        
        try saveGamesThrowing()
        Logger.shared.info("成功更新游戏状态: \(games[index].gameName)")
    }
    
    /// 根据 ID 更新游戏状态（静默版本）
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - isRunning: 是否正在运行
    ///   - lastPlayed: 最后游玩时间
    /// - Returns: 是否更新成功
    func updateGameStatusSilently(id: String, isRunning: Bool, lastPlayed: Date = Date()) -> Bool {
        Task {
            do {
                try await updateGameStatus(id: id, isRunning: isRunning, lastPlayed: lastPlayed)
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
        guard let index = games.firstIndex(where: { $0.id == id }) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 Java 路径的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_java",
                level: .notification
            )
        }
        
        await MainActor.run {
            var game = games[index]
            game.javaPath = javaPath
            games[index] = game
        }
        try saveGamesThrowing()
        Logger.shared.info("成功更新游戏 Java 路径: \(games[index].gameName)")
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
        guard let index = games.firstIndex(where: { $0.id == id }) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 JVM 参数的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_jvm",
                level: .notification
            )
        }
        
        await MainActor.run {
            var game = games[index]
            game.jvmArguments = jvmArguments
            games[index] = game
        }
        try saveGamesThrowing()
        Logger.shared.info("成功更新游戏 JVM 参数: \(games[index].gameName)")
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
        guard let index = games.firstIndex(where: { $0.id == id }) else {
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
        
        await MainActor.run {
            var game = games[index]
            game.xms = xms
            game.xmx = xmx
            games[index] = game
        }
        try saveGamesThrowing()
        Logger.shared.info("成功更新游戏内存大小: \(games[index].gameName)")
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
            } catch {
                GlobalErrorHandler.shared.handle(error)
                await MainActor.run {
                    games = []
                }
            }
        }
    }
    
    /// 从 UserDefaults 加载游戏列表（抛出异常版本）
    /// - Throws: GlobalError 当操作失败时
    func loadGamesThrowing() async throws {
        guard let savedGamesData = UserDefaults.standard.data(forKey: gamesKey) else {
            await MainActor.run {
                games = []
            }
            return
        }

        do {
            let decoder = JSONDecoder()
            let allGames = try decoder.decode([GameVersionInfo].self, from: savedGamesData)
            
            // 只保留本地 profiles 目录下实际存在的游戏（只判断文件夹名）
            guard let profilesDir = AppPaths.profileRootDirectory else {
                throw GlobalError.configuration(
                    chineseMessage: "无法获取游戏配置根目录",
                    i18nKey: "error.configuration.game_profiles_root_not_found",
                    level: .popup
                )
            }
            
            let fileManager = FileManager.default
            let localGameNames: Set<String>
            
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: profilesDir.path)
                localGameNames = Set(contents)
            } catch {
                throw GlobalError.validation(
                    chineseMessage: "加载游戏列表失败：\(error.localizedDescription)",
                    i18nKey: "error.validation.game_list_load_failed",
                    level: .notification
                )
            }
            
            let validGames = allGames.filter { localGameNames.contains($0.gameName) }
            await MainActor.run {
                games = validGames
            }
            
            Logger.shared.info("成功加载 \(validGames.count) 个游戏")
        } catch let error as GlobalError {
            throw error
        } catch {
            throw GlobalError.validation(
                chineseMessage: "加载游戏列表失败：\(error.localizedDescription)",
                i18nKey: "error.validation.game_list_load_failed",
                level: .notification
            )
        }
    }

    /// 保存游戏列表到 UserDefaults（静默版本）
    private func saveGames() {
        do {
            try saveGamesThrowing()
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }
    
    /// 保存游戏列表到 UserDefaults（抛出异常版本）
    /// - Throws: GlobalError 当操作失败时
    private func saveGamesThrowing() throws {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(games)
            UserDefaults.standard.set(encodedData, forKey: gamesKey)
            Logger.shared.debug("成功保存 \(games.count) 个游戏")
        } catch {
            throw GlobalError.validation(
                chineseMessage: "保存游戏列表失败：\(error.localizedDescription)",
                i18nKey: "error.validation.game_list_save_failed",
                level: .notification
            )
        }
    }
}
