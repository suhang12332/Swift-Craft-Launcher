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
    /// 检查各个类型是否存在（在后台执行，避免主线程 FileManager）
    private func checkTypesAvailability() async {
        let name = gameName
        let (worlds, screenshots, servers, litematica, logs) = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let profileDir = AppPaths.profileDirectory(gameName: name)
            let savesPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
            let screenshotsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)
            let logsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
            let serversDatURL = profileDir.appendingPathComponent("servers.dat")
            let schematicsDir = AppPaths.schematicsDirectory(gameName: name)
            return (
                fm.fileExists(atPath: savesPath.path),
                fm.fileExists(atPath: screenshotsPath.path),
                fm.fileExists(atPath: serversDatURL.path),
                fm.fileExists(atPath: schematicsDir.path),
                fm.fileExists(atPath: logsPath.path)
            )
        }.value
        hasWorldsType = worlds
        hasScreenshotsType = screenshots
        hasServersType = servers
        hasLitematicaType = litematica
        hasLogsType = logs
    }

    private func fetchData() async {
        await checkTypesAvailability()

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
    /// 加载世界信息（目录与文件 I/O 在后台执行）
    private func loadWorlds() async {
        isLoadingWorlds = true
        defer { isLoadingWorlds = false }

        guard savesDirectory != nil else {
            worlds = []
            return
        }
        let name = gameName
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadWorldsFromDirectory(gameName: name)
        }.value
        worlds = result
    }

    /// 加载截图信息（目录与文件 I/O 在后台执行）
    private func loadScreenshots() async {
        isLoadingScreenshots = true
        defer { isLoadingScreenshots = false }

        guard screenshotsDirectory != nil else {
            screenshots = []
            return
        }
        let name = gameName
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadScreenshotsFromDirectory(gameName: name)
        }.value
        screenshots = result
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

    /// 加载日志文件信息（目录与文件 I/O 在后台执行）
    private func loadLogs() async {
        isLoadingLogs = true
        defer { isLoadingLogs = false }

        guard logsDirectory != nil else {
            logs = []
            return
        }
        let name = gameName
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadLogsFromDirectory(gameName: name)
        }.value
        logs = result
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

    // MARK: - 后台加载静态方法（避免主线程 FileManager / Data(contentsOf:)）
    nonisolated private static func loadWorldsFromDirectory(gameName: String) -> [WorldInfo] {
        let savesPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: savesPath.path) else { return [] }
        do {
            let contents = try fm.contentsOfDirectory(
                at: savesPath,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            var loadedWorlds: [WorldInfo] = []
            for worldPath in contents {
                guard let isDirectory = try? worldPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      isDirectory == true else { continue }
                let worldName = worldPath.lastPathComponent
                let levelDatPath = worldPath.appendingPathComponent("level.dat")
                var lastPlayed: Date?
                if let modDate = try? worldPath.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                    lastPlayed = modDate
                }
                guard fm.fileExists(atPath: levelDatPath.path) else {
                    loadedWorlds.append(WorldInfo(name: worldName, path: worldPath, lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil))
                    continue
                }
                do {
                    let data = try Data(contentsOf: levelDatPath)
                    let parser = NBTParser(data: data)
                    let nbtData = try parser.parse()
                    guard let dataTag = nbtData["Data"] as? [String: Any] else {
                        loadedWorlds.append(WorldInfo(name: worldName, path: worldPath, lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil))
                        continue
                    }
                    if let ts = WorldNBTMapper.readInt64(dataTag["LastPlayed"]) {
                        // LastPlayed 为毫秒时间戳
                        lastPlayed = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
                    }

                    // 统一使用 readInt64，兼容旧版与 26+ 新版存档的数值类型
                    let gameMode: String? = {
                        if let v = WorldNBTMapper.readInt64(dataTag["GameType"]) {
                            return WorldNBTMapper.mapGameMode(Int(v))
                        }
                        return nil
                    }()

                    let difficulty: String? = {
                        if let v = WorldNBTMapper.readInt64(dataTag["Difficulty"]) {
                            return WorldNBTMapper.mapDifficulty(Int(v))
                        }
                        // 26+ 新版存档：difficulty_settings.difficulty 为字符串（peaceful/easy/normal/hard）
                        if let ds = dataTag["difficulty_settings"] as? [String: Any],
                           let diffStr = ds["difficulty"] as? String {
                            return WorldNBTMapper.mapDifficultyString(diffStr)
                        }
                        return nil
                    }()

                    let version: String? = (dataTag["Version"] as? [String: Any])?["Name"] as? String
                    // 极限模式 / 是否允许作弊（不同版本字段位置不同）
                    let hardcore: Bool? = {
                        if let v = WorldNBTMapper.readBoolFlag(dataTag["hardcore"]) { return v }
                        if let ds = dataTag["difficulty_settings"] as? [String: Any],
                           let v = WorldNBTMapper.readBoolFlag(ds["hardcore"]) { return v }
                        return nil
                    }()
                    let cheats: Bool? = WorldNBTMapper.readBoolFlag(dataTag["allowCommands"])

                    // 种子字段在新旧版本之间有差异：旧版 level.dat 使用 RandomSeed，新版拆到 world_gen_settings.dat
                    let seed: Int64? = WorldNBTMapper.readSeed(from: dataTag, worldPath: worldPath)

                    loadedWorlds.append(
                        WorldInfo(
                            name: worldName,
                            path: worldPath,
                            lastPlayed: lastPlayed,
                            gameMode: gameMode,
                            difficulty: difficulty,
                            hardcore: hardcore,
                            cheats: cheats,
                            version: version,
                            seed: seed
                        )
                    )
                } catch {
                    Logger.shared.error("解析 level.dat 失败 (\(worldName)): \(error.localizedDescription)")
                    loadedWorlds.append(WorldInfo(name: worldName, path: worldPath, lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, hardcore: nil, cheats: nil, version: nil, seed: nil))
                }
            }
            loadedWorlds.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            return loadedWorlds
        } catch {
            Logger.shared.error("加载世界信息失败: \(error.localizedDescription)")
            return []
        }
    }

    nonisolated private static func loadScreenshotsFromDirectory(gameName: String) -> [ScreenshotInfo] {
        let screenshotsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: screenshotsPath.path) else { return [] }
        do {
            let contents = try fm.contentsOfDirectory(
                at: screenshotsPath,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            var loaded: [ScreenshotInfo] = []
            for screenshotPath in contents {
                guard let isFile = try? screenshotPath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isFile == true else { continue }
                let ext = screenshotPath.pathExtension.lowercased()
                guard ["png", "jpg", "jpeg"].contains(ext) else { continue }
                let creationDate = try? screenshotPath.resourceValues(forKeys: [.creationDateKey]).creationDate
                let fileSize = (try? screenshotPath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                loaded.append(ScreenshotInfo(name: screenshotPath.lastPathComponent, path: screenshotPath, createdDate: creationDate, fileSize: Int64(fileSize)))
            }
            loaded.sort { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
            return loaded
        } catch {
            Logger.shared.error("加载截图信息失败: \(error.localizedDescription)")
            return []
        }
    }

    nonisolated private static func loadLogsFromDirectory(gameName: String) -> [LogInfo] {
        let logsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: logsPath.path) else { return [] }
        do {
            let contents = try fm.contentsOfDirectory(
                at: logsPath,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            var loaded: [LogInfo] = []
            for logPath in contents {
                guard let isFile = try? logPath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                      isFile == true else { continue }
                guard logPath.pathExtension.lowercased() == "log" else { continue }
                let name = logPath.lastPathComponent
                let creationDate = try? logPath.resourceValues(forKeys: [.creationDateKey]).creationDate
                let fileSize = (try? logPath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let fileNameLower = name.lowercased()
                let isCrashLog = fileNameLower.contains("crash") || fileNameLower.contains("error") || fileNameLower.contains("exception")
                loaded.append(LogInfo(name: name, path: logPath, createdDate: creationDate, fileSize: Int64(fileSize), isCrashLog: isCrashLog))
            }
            loaded.sort { if $0.isCrashLog != $1.isCrashLog { return $0.isCrashLog }; return ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
            return loaded
        } catch {
            Logger.shared.error("加载日志信息失败: \(error.localizedDescription)")
            return []
        }
    }
}
