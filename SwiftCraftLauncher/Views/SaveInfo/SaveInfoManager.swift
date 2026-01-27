import Foundation
import Combine

// MARK: - 存档信息管理器
@MainActor
final class SaveInfoManager: ObservableObject {
    // MARK: - Private Types
    /// 世界信息解析结果
    private struct WorldParseResult {
        let lastPlayed: Date?
        let gameMode: String?
        let difficulty: String?
        let version: String?
        let seed: Int64?
    }

    // MARK: - Published Properties
    let gameName: String
    @Published private(set) var worlds: [WorldInfo] = []
    @Published private(set) var screenshots: [ScreenshotInfo] = []
    @Published private(set) var servers: [ServerAddress] = []
    @Published private(set) var litematicaFiles: [LitematicaInfo] = []
    @Published private(set) var logs: [LogInfo] = []
    @Published private(set) var isLoading: Bool = true

    // 各个类型的加载状态
    @Published private(set) var isLoadingWorlds: Bool = false
    @Published private(set) var isLoadingScreenshots: Bool = false
    @Published private(set) var isLoadingServers: Bool = false
    @Published private(set) var isLoadingLitematica: Bool = false
    @Published private(set) var isLoadingLogs: Bool = false

    // 各个类型是否存在（目录或资源是否存在）
    @Published private(set) var hasWorldsType: Bool = false
    @Published private(set) var hasScreenshotsType: Bool = false
    @Published private(set) var hasServersType: Bool = false
    @Published private(set) var hasLitematicaType: Bool = false
    @Published private(set) var hasLogsType: Bool = false

    // MARK: - Private Properties
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization
    init(gameName: String) {
        self.gameName = gameName
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Paths
    /// 获取游戏存档目录（从 profile 目录下读取）
    private var savesDirectory: URL? {
        let savesPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)

        // 如果目录不存在，返回 nil（跳过）
        guard FileManager.default.fileExists(atPath: savesPath.path) else {
            return nil
        }

        return savesPath
    }

    /// 获取游戏截图目录（从 profile 目录下读取）
    private var screenshotsDirectory: URL? {
        let screenshotsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)

        // 如果目录不存在，返回 nil（跳过）
        guard FileManager.default.fileExists(atPath: screenshotsPath.path) else {
            return nil
        }

        return screenshotsPath
    }

    /// 获取游戏日志目录（从 profile 目录下读取）
    private var logsDirectory: URL? {
        let logsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)

        // 如果目录不存在，返回 nil（跳过）
        guard FileManager.default.fileExists(atPath: logsPath.path) else {
            return nil
        }

        return logsPath
    }

    // MARK: - Public Methods
    func loadData() async {
        loadTask?.cancel()
        loadTask = Task {
            await fetchData()
        }
    }

    func clearCache() {
        loadTask?.cancel()
        resetData()
    }

    // MARK: - Private Methods
    /// 检查各个类型是否存在
    private func checkTypesAvailability() {
        // 检查世界类型
        hasWorldsType = savesDirectory != nil

        // 检查截图类型
        hasScreenshotsType = screenshotsDirectory != nil

        // 检查服务器类型（检查 servers.dat 文件是否存在）
        let profileDir = AppPaths.profileDirectory(gameName: gameName)
        let serversDatURL = profileDir.appendingPathComponent("servers.dat")
        hasServersType = FileManager.default.fileExists(atPath: serversDatURL.path)

        // 检查 Litematica 类型（检查 schematics 目录是否存在）
        let schematicsDir = AppPaths.schematicsDirectory(gameName: gameName)
        hasLitematicaType = FileManager.default.fileExists(atPath: schematicsDir.path)

        // 检查日志类型
        hasLogsType = logsDirectory != nil
    }

    private func fetchData() async {
        // 先检查哪些类型存在
        checkTypesAvailability()

        isLoading = true

        await withTaskGroup(of: Void.self) { group in
            // 只加载存在的类型
            if hasWorldsType {
                group.addTask { [weak self] in
                    await self?.loadWorlds()
                }
            }

            if hasScreenshotsType {
                group.addTask { [weak self] in
                    await self?.loadScreenshots()
                }
            }

            if hasServersType {
                group.addTask { [weak self] in
                    await self?.loadServers()
                }
            }

            if hasLitematicaType {
                group.addTask { [weak self] in
                    await self?.loadLitematicaFiles()
                }
            }

            if hasLogsType {
                group.addTask { [weak self] in
                    await self?.loadLogs()
                }
            }
        }

        isLoading = false
    }

    // MARK: - Helper (Worlds)
    /// 将 GameType 数值映射为本地化描述
    private func mapGameMode(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.game_mode.survival".localized()
        case 1: return "saveinfo.world.game_mode.creative".localized()
        case 2: return "saveinfo.world.game_mode.adventure".localized()
        case 3: return "saveinfo.world.game_mode.spectator".localized()
        default: return "saveinfo.world.game_mode.unknown".localized()
        }
    }

    /// 将 Difficulty 数值映射为本地化描述
    private func mapDifficulty(_ value: Int) -> String {
        switch value {
        case 0: return "saveinfo.world.difficulty.peaceful".localized()
        case 1: return "saveinfo.world.difficulty.easy".localized()
        case 2: return "saveinfo.world.difficulty.normal".localized()
        case 3: return "saveinfo.world.difficulty.hard".localized()
        default: return "saveinfo.world.difficulty.unknown".localized()
        }
    }

    /// 加载世界信息
    private func loadWorlds() async {
        isLoadingWorlds = true
        defer { isLoadingWorlds = false }

        guard let savesDir = savesDirectory else {
            worlds = []
            return
        }

        var loadedWorlds: [WorldInfo] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: savesDir,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            for worldPath in contents {
                guard let isDirectory = try? worldPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      isDirectory == true else {
                    continue
                }

                let worldName = worldPath.lastPathComponent
                let levelDatPath = worldPath.appendingPathComponent("level.dat")

                // 读取世界信息
                let parseResult: WorldParseResult = {
                    // 获取文件修改时间作为最后游玩时间（作为兜底）
                    var lastPlayed: Date?
                    if let modDate = try? worldPath.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        lastPlayed = modDate
                    }

                    guard FileManager.default.fileExists(atPath: levelDatPath.path) else {
                        return WorldParseResult(lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil)
                    }

                    // 使用 NBTParser 解析 level.dat
                    do {
                        let data = try Data(contentsOf: levelDatPath)
                        let parser = NBTParser(data: data)
                        let nbtData = try parser.parse()

                        guard let dataTag = nbtData["Data"] as? [String: Any] else {
                            return WorldParseResult(lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil)
                        }

                        // LastPlayed 为毫秒时间戳
                        if let ts = dataTag["LastPlayed"] as? Int64 {
                            lastPlayed = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
                        } else if let ts = dataTag["LastPlayed"] as? Int {
                            lastPlayed = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
                        }

                        // GameType: 0 生存, 1 创造, 2 冒险, 3 旁观
                        let gameMode: String?
                        if let gt = dataTag["GameType"] as? Int {
                            gameMode = mapGameMode(gt)
                        } else if let gt32 = dataTag["GameType"] as? Int32 {
                            gameMode = mapGameMode(Int(gt32))
                        } else {
                            gameMode = nil
                        }

                        // Difficulty: 0 和平, 1 简单, 2 普通, 3 困难
                        let difficulty: String?
                        if let diff = dataTag["Difficulty"] as? Int {
                            difficulty = mapDifficulty(diff)
                        } else if let diff8 = dataTag["Difficulty"] as? Int8 {
                            difficulty = mapDifficulty(Int(diff8))
                        } else {
                            difficulty = nil
                        }

                        // Version 信息
                        let version: String?
                        if let versionTag = dataTag["Version"] as? [String: Any] {
                            version = versionTag["Name"] as? String
                        } else {
                            version = nil
                        }

                        // 世界种子
                        let seed: Int64?
                        if let s = dataTag["RandomSeed"] as? Int64 {
                            seed = s
                        } else if let s = dataTag["RandomSeed"] as? Int {
                            seed = Int64(s)
                        } else {
                            seed = nil
                        }

                        return WorldParseResult(lastPlayed: lastPlayed, gameMode: gameMode, difficulty: difficulty, version: version, seed: seed)
                    } catch {
                        Logger.shared.error("解析 level.dat 失败 (\(worldName)): \(error.localizedDescription)")
                        return WorldParseResult(lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil)
                    }
                }()

                let worldInfo = WorldInfo(
                    name: worldName,
                    path: worldPath,
                    lastPlayed: parseResult.lastPlayed,
                    gameMode: parseResult.gameMode,
                    difficulty: parseResult.difficulty,
                    version: parseResult.version,
                    seed: parseResult.seed
                )

                loadedWorlds.append(worldInfo)
            }

            // 按最后游玩时间排序
            loadedWorlds.sort { world1, world2 in
                let date1 = world1.lastPlayed ?? Date.distantPast
                let date2 = world2.lastPlayed ?? Date.distantPast
                return date1 > date2
            }

            worlds = loadedWorlds
        } catch {
            Logger.shared.error("加载世界信息失败: \(error.localizedDescription)")
            worlds = []
        }
    }

    /// 加载截图信息
    private func loadScreenshots() async {
        isLoadingScreenshots = true
        defer { isLoadingScreenshots = false }

        guard let screenshotsDir = screenshotsDirectory else {
            screenshots = []
            return
        }

        var loadedScreenshots: [ScreenshotInfo] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: screenshotsDir,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .creationDateKey,
                    .fileSizeKey,
                ],
                options: [.skipsHiddenFiles]
            )

            for screenshotPath in contents {
                guard let isFile = try? screenshotPath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isFile == true else {
                    continue
                }

                // 只处理图片文件
                let fileExtension = screenshotPath.pathExtension.lowercased()
                guard ["png", "jpg", "jpeg"].contains(fileExtension) else {
                    continue
                }

                let screenshotName = screenshotPath.lastPathComponent
                let creationDate = try? screenshotPath.resourceValues(forKeys: [.creationDateKey]).creationDate
                let fileSize = (try? screenshotPath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

                let screenshotInfo = ScreenshotInfo(
                    name: screenshotName,
                    path: screenshotPath,
                    createdDate: creationDate,
                    fileSize: Int64(fileSize)
                )

                loadedScreenshots.append(screenshotInfo)
            }

            // 按创建时间排序
            loadedScreenshots.sort { screenshot1, screenshot2 in
                let date1 = screenshot1.createdDate ?? Date.distantPast
                let date2 = screenshot2.createdDate ?? Date.distantPast
                return date1 > date2
            }

            screenshots = loadedScreenshots
        } catch {
            Logger.shared.error("加载截图信息失败: \(error.localizedDescription)")
            screenshots = []
        }
    }

    /// 加载服务器地址信息（仅从 servers.dat 读取）
    private func loadServers() async {
        isLoadingServers = true
        defer { isLoadingServers = false }

        do {
            servers = try await ServerAddressService.shared.loadServerAddresses(for: gameName)
        } catch {
            Logger.shared.error("加载服务器地址信息失败: \(error.localizedDescription)")
            // 如果加载失败，返回空数组
            servers = []
        }
    }

    /// 加载 Litematica 投影文件信息
    private func loadLitematicaFiles() async {
        isLoadingLitematica = true
        defer { isLoadingLitematica = false }

        do {
            litematicaFiles = try await LitematicaService.shared.loadLitematicaFiles(for: gameName)
        } catch {
            Logger.shared.error("加载 Litematica 文件信息失败: \(error.localizedDescription)")
            // 如果加载失败，返回空数组
            litematicaFiles = []
        }
    }

    /// 加载日志文件信息
    private func loadLogs() async {
        isLoadingLogs = true
        defer { isLoadingLogs = false }

        guard let logsDir = logsDirectory else {
            logs = []
            return
        }

        var loadedLogs: [LogInfo] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: logsDir,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .creationDateKey,
                    .fileSizeKey,
                ],
                options: [.skipsHiddenFiles]
            )

            for logPath in contents {
                guard let isFile = try? logPath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isFile == true else {
                    continue
                }

                // 只处理.log结尾的文件
                let fileExtension = logPath.pathExtension.lowercased()
                guard fileExtension == "log" else {
                    continue
                }

                let logName = logPath.lastPathComponent
                let creationDate = try? logPath.resourceValues(forKeys: [.creationDateKey]).creationDate
                let fileSize = (try? logPath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

                // 判断是否为崩溃日志（文件名包含crash或error等关键词）
                let fileNameLower = logName.lowercased()
                let isCrashLog = fileNameLower.contains("crash") ||
                                fileNameLower.contains("error") ||
                                fileNameLower.contains("exception")

                let logInfo = LogInfo(
                    name: logName,
                    path: logPath,
                    createdDate: creationDate,
                    fileSize: Int64(fileSize),
                    isCrashLog: isCrashLog
                )

                loadedLogs.append(logInfo)
            }

            // 按创建时间排序，崩溃日志优先显示
            loadedLogs.sort { log1, log2 in
                // 崩溃日志优先
                if log1.isCrashLog != log2.isCrashLog {
                    return log1.isCrashLog
                }
                // 然后按时间排序
                let date1 = log1.createdDate ?? Date.distantPast
                let date2 = log2.createdDate ?? Date.distantPast
                return date1 > date2
            }

            logs = loadedLogs
        } catch {
            Logger.shared.error("加载日志信息失败: \(error.localizedDescription)")
            logs = []
        }
    }

    private func resetData() {
        worlds.removeAll(keepingCapacity: false)
        screenshots.removeAll(keepingCapacity: false)
        servers.removeAll(keepingCapacity: false)
        litematicaFiles.removeAll(keepingCapacity: false)
        logs.removeAll(keepingCapacity: false)
        isLoading = false

        // 重置各个类型的加载状态
        isLoadingWorlds = false
        isLoadingScreenshots = false
        isLoadingServers = false
        isLoadingLitematica = false
        isLoadingLogs = false

        // 重置类型存在状态
        hasWorldsType = false
        hasScreenshotsType = false
        hasServersType = false
        hasLitematicaType = false
        hasLogsType = false
    }
}
