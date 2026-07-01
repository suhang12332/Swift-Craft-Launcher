//
//  GameRepository.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation

/// A repository that manages the persistence and retrieval of game version information.
///
/// `GameRepository` serves as the primary data access layer for game instances,
/// coordinating between the local SQLite database and the in-memory cache.
class GameRepository: ObservableObject {
    /// A dictionary of game instances keyed by their working path.
    @Published private(set) var gamesByWorkingPath: [String: [GameVersionInfo]] = [:]

    /// A dictionary of corrupted game names keyed by their working path.
    ///
    /// A game is considered corrupted when its database record and local directory
    /// are inconsistent.
    @Published private(set) var corruptedGamesByWorkingPath: [String: [String]] = [:]

    /// All working paths and their associated game counts from the database.
    @Published private(set) var workingPathOptions: [(path: String, count: Int)] = []

    var games: [GameVersionInfo] {
        gamesByWorkingPath[currentWorkingPath] ?? []
    }

    /// The corrupted game names for the current working path.
    var corruptedGames: [String] {
        corruptedGamesByWorkingPath[currentWorkingPath] ?? []
    }

    private var currentWorkingPath: String {
        workingPathProvider.currentWorkingPath
    }

    private let workingPathProvider: WorkingPathProviding
    private let database: GameVersionDatabase
    private let errorHandler: GlobalErrorHandler
    private let modScanner: ModScanner
    private var workingPathCancellable: AnyCancellable?
    private var lastWorkingPath: String = ""
    private var initialLoadTask: Task<Void, Never>?
    private var workspaceSwitchTask: Task<Void, Never>?
    private var hasLoadedInitialData = false

    @Published var workingPathChanged: Bool = false

    /// Creates a game repository.
    ///
    /// - Parameters:
    ///   - workingPathProvider: The provider for the current working path.
    ///   - errorHandler: The handler for global errors.
    ///   - modScanner: The scanner for mod directories.
    init(
        workingPathProvider: WorkingPathProviding = AppServices.generalSettingsManager,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        modScanner: ModScanner = AppServices.modScanner,
    ) {
        self.workingPathProvider = workingPathProvider
        self.errorHandler = errorHandler
        self.modScanner = modScanner
        let dbPath = AppPaths.gameVersionDatabase.path
        database = GameVersionDatabase(dbPath: dbPath)

        lastWorkingPath = currentWorkingPath

        DispatchQueue.main.async { [weak self] in
            self?.setupWorkingPathObserver()
        }
    }

    private func initializeDatabase() async throws {
        let dataDir = AppPaths.dataDirectory
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        try database.initialize()
    }

    deinit {
        workingPathCancellable?.cancel()
    }

    private func setupWorkingPathObserver() {
        lastWorkingPath = currentWorkingPath

        workingPathCancellable = workingPathProvider.workingPathWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newPath = currentWorkingPath
                if newPath != lastWorkingPath {
                    lastWorkingPath = newPath
                    workingPathChanged = true
                    workspaceSwitchTask?.cancel()
                    workspaceSwitchTask = Task { @MainActor in
                        do {
                            try await self.loadGamesThrowing()
                            if !Task.isCancelled {
                                await self.scanAllGamesModsDirectory()
                            }
                            self.workingPathChanged = false
                        } catch {
                            if !(error is CancellationError) {
                                self.errorHandler.handle(error)
                            }
                            self.workingPathChanged = false
                        }
                    }
                }
            }
    }

    /// Loads initial data if it has not already been loaded.
    @MainActor
    func loadInitialDataIfNeeded() async {
        if hasLoadedInitialData {
            return
        }
        if let initialLoadTask {
            await initialLoadTask.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await initializeDatabase()
                try await loadGamesThrowing()
                await scanAllGamesModsDirectory()
                await refreshWorkingPathOptions()
                hasLoadedInitialData = true
            } catch {
                errorHandler.handle(error)
                await MainActor.run {
                    self.gamesByWorkingPath = [:]
                }
            }
        }

        initialLoadTask = task
        await task.value
        initialLoadTask = nil
    }

    /// Reloads all working paths and their game counts.
    func refreshWorkingPathOptions() async {
        let options = await fetchAllWorkingPathsWithCounts()
        await MainActor.run {
            self.workingPathOptions = options
        }
    }

    func addGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.saveGame(gameToSave, workingPath: workingPath)
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

        AppLog.game.info("成功添加游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    func addGameSilently(_ game: GameVersionInfo) {
        Task {
            do {
                try await addGame(game)
            } catch {
                self.errorHandler.handle(error)
            }
        }
    }

    func deleteGame(id: String) async throws {
        let workingPath = currentWorkingPath
        guard let game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要删除的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_delete",
                level: .notification,
            )
        }
        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.deleteGame(id: id)
        }.value

        await MainActor.run {
            gamesByWorkingPath[workingPath]?.removeAll { $0.id == id }
        }

        AppLog.game.info("成功删除游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    func deleteGameSilently(id: String) {
        Task {
            do {
                try await deleteGame(id: id)
            } catch {
                self.errorHandler.handle(error)
            }
        }
    }

    /// Deletes all games with the specified name in the current working path.
    ///
    /// - Parameter gameName: The name of the games to delete.
    func deleteGamesByName(_ gameName: String) async throws {
        let workingPath = currentWorkingPath
        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.deleteGames(workingPath: workingPath, gameName: gameName)
        }.value

        await MainActor.run {
            gamesByWorkingPath[workingPath]?.removeAll { $0.gameName == gameName }
            corruptedGamesByWorkingPath[workingPath]?.removeAll { $0 == gameName }
        }

        AppLog.game.info("成功删除名称为 \(gameName) 的游戏记录（工作路径: \(workingPath)）")
    }

    func getGame(by id: String) -> GameVersionInfo? {
        games.first { $0.id == id }
    }

    func getGameByName(by gameName: String) -> GameVersionInfo? {
        games.first { $0.gameName == gameName }
    }

    func updateGame(_ game: GameVersionInfo) async throws {
        let workingPath = currentWorkingPath
        let gameToSave = game

        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.saveGame(gameToSave, workingPath: workingPath)
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

        AppLog.game.info("成功更新游戏: \(game.gameName) (工作路径: \(workingPath))")
    }

    func updateGameSilently(_ game: GameVersionInfo) -> Bool {
        Task {
            do {
                try await updateGame(game)
            } catch {
                self.errorHandler.handle(error)
            }
        }
        return true
    }

    func updateGameLastPlayed(id: String, lastPlayed: Date = Date()) async throws {
        let workingPath = currentWorkingPath
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新状态的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_status",
                level: .notification,
            )
        }
        try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            try self.database.updateLastPlayed(id: id, lastPlayed: lastPlayed)
        }.value

        game.lastPlayed = lastPlayed
        let updatedGame = game
        await MainActor.run {
            if let index = gamesByWorkingPath[workingPath]?.firstIndex(where: { $0.id == id }) {
                gamesByWorkingPath[workingPath]?[index] = updatedGame
            }
        }

        AppLog.game.info("成功更新游戏最后游玩时间: \(game.gameName) (工作路径: \(workingPath))")
    }

    func updateGameLastPlayedSilently(id: String, lastPlayed: Date = Date()) -> Bool {
        Task {
            do {
                try await updateGameLastPlayed(id: id, lastPlayed: lastPlayed)
            } catch {
                self.errorHandler.handle(error)
            }
        }
        return true
    }

    func updateJavaPath(id: String, javaPath: String) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 Java 路径的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_java",
                level: .notification,
            )
        }

        game.javaPath = javaPath
        try await updateGame(game)
        AppLog.game.info("成功更新游戏 Java 路径: \(game.gameName)")
    }

    func updateJavaPathSilently(id: String, javaPath: String) -> Bool {
        Task {
            do {
                try await updateJavaPath(id: id, javaPath: javaPath)
            } catch {
                self.errorHandler.handle(error)
            }
        }
        return true
    }

    func updateJvmArguments(id: String, jvmArguments: String) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新 JVM 参数的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_jvm",
                level: .notification,
            )
        }

        game.jvmArguments = jvmArguments
        try await updateGame(game)
        AppLog.game.info("成功更新游戏 JVM 参数: \(game.gameName)")
    }

    func updateJvmArgumentsSilently(id: String, jvmArguments: String) -> Bool {
        Task {
            do {
                try await updateJvmArguments(id: id, jvmArguments: jvmArguments)
            } catch {
                self.errorHandler.handle(error)
            }
        }
        return true
    }

    func updateMemorySize(id: String, xms: Int, xmx: Int) async throws {
        guard var game = getGame(by: id) else {
            throw GlobalError.validation(
                chineseMessage: "找不到要更新内存大小的游戏：\(id)",
                i18nKey: "error.validation.game_not_found_memory",
                level: .notification,
            )
        }

        guard xms > 0, xmx > 0, xms <= xmx else {
            throw GlobalError.validation(
                chineseMessage: "无效的内存参数：xms=\(xms), xmx=\(xmx)",
                i18nKey: "error.validation.invalid_memory_params",
                level: .notification,
            )
        }

        game.xms = xms
        game.xmx = xmx
        try await updateGame(game)
        AppLog.game.info("成功更新游戏内存大小: \(game.gameName)")
    }

    func updateMemorySizeSilently(id: String, xms: Int, xmx: Int) -> Bool {
        Task {
            do {
                try await updateMemorySize(id: id, xms: xms, xmx: xmx)
            } catch {
                self.errorHandler.handle(error)
            }
        }
        return true
    }

    func loadGames() {
        loadGamesSafely()
    }

    private func loadGamesSafely() {
        Task {
            do {
                try await loadGamesThrowing()

                await scanAllGamesModsDirectory()
            } catch {
                self.errorHandler.handle(error)
                await MainActor.run {
                    gamesByWorkingPath = [:]
                }
            }
        }
    }

    private func scanAllGamesModsDirectory() async {
        let games = games
        AppLog.game.info("开始扫描 \(games.count) 个游戏的 mods 目录")

        await withTaskGroup(of: Void.self) { group in
            for game in games {
                group.addTask {
                    await self.modScanner.scanGameModsDirectory(game: game)
                }
            }
        }

        AppLog.game.info("完成所有游戏的 mods 目录扫描")
    }

    /// Fetches all working paths with their game counts from the database.
    func fetchAllWorkingPathsWithCounts() async -> [(path: String, count: Int)] {
        let currentPath = currentWorkingPath
        let rows: [(path: String, count: Int)]
        do {
            rows = try await Task.detached(priority: .userInitiated) {
                try? self.database.initialize()
                return try self.database.loadWorkingPathsWithCounts()
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

    func loadGamesThrowing() async throws {
        let workingPath = currentWorkingPath

        let (validGames, corruptedNames, pathForLog): ([GameVersionInfo], [String], String) = try await Task.detached(priority: .userInitiated) {
            try? self.database.initialize()
            let games = try self.database.loadGames(workingPath: workingPath)
            let fm = FileManager.default
            let baseURL = URL(fileURLWithPath: workingPath, isDirectory: true)
            let profileRootDir = baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
            let localGameNames: Set<String>
            do {
                if fm.fileExists(atPath: profileRootDir.path) {
                    let contents = try fm.contentsOfDirectory(atPath: profileRootDir.path)
                    let filtered = contents.filter { !$0.hasPrefix(".") }
                    localGameNames = Set(filtered)
                } else {
                    localGameNames = []
                }
            } catch {
                AppLog.game.error("无法读取工作路径的游戏目录: \(workingPath), 错误: \(error.localizedDescription)")
                localGameNames = []
            }
            let valid = games.filter { localGameNames.contains($0.gameName) }
            let dbGameNames = Set(games.map(\.gameName))
            let missingFolders = dbGameNames.subtracting(localGameNames)
            let missingDatabase = localGameNames.subtracting(dbGameNames)
            let corrupted = Array(missingFolders.union(missingDatabase)).sorted()
            return (valid, corrupted, workingPath)
        }.value

        await MainActor.run {
            gamesByWorkingPath[workingPath] = validGames
            corruptedGamesByWorkingPath[workingPath] = corruptedNames
        }

        AppLog.game.info("成功加载 \(validGames.count) 个游戏（工作路径: \(pathForLog)）")
    }
}
