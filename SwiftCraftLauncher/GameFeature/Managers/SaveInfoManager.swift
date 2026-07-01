//
//  SaveInfoManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation

/// Loads and manages save information including worlds, screenshots, servers,
/// litematica files, and logs for a specific game instance.
@MainActor
final class SaveInfoManager: ObservableObject {
    private struct WorldParseResult {
        let lastPlayed: Date?
        let gameMode: String?
        let difficulty: String?
        let version: String?
        let seed: Int64?
    }

    let gameName: String
    @Published private(set) var worlds: [WorldInfo] = []
    @Published private(set) var screenshots: [ScreenshotInfo] = []
    @Published private(set) var servers: [ServerAddress] = []
    @Published private(set) var litematicaFiles: [LitematicaInfo] = []
    @Published private(set) var logs: [LogInfo] = []
    @Published private(set) var isLoading: Bool = true

    @Published private(set) var isLoadingWorlds: Bool = false
    @Published private(set) var isLoadingScreenshots: Bool = false
    @Published private(set) var isLoadingServers: Bool = false
    @Published private(set) var isLoadingLitematica: Bool = false
    @Published private(set) var isLoadingLogs: Bool = false

    @Published private(set) var hasWorldsType: Bool = false
    @Published private(set) var hasScreenshotsType: Bool = false
    @Published private(set) var hasLitematicaType: Bool = false
    @Published private(set) var hasLogsType: Bool = false

    private var loadTask: Task<Void, Never>?
    private let serverAddressService: ServerAddressService
    private let litematicaService: LitematicaService

    init(
        gameName: String,
        serverAddressService: ServerAddressService = AppServices.serverAddressService,
        litematicaService: LitematicaService = AppServices.litematicaService,
    ) {
        self.gameName = gameName
        self.serverAddressService = serverAddressService
        self.litematicaService = litematicaService
    }

    deinit {
        loadTask?.cancel()
    }

    private var savesDirectory: URL? {
        let savesPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)

        guard FileManager.default.fileExists(atPath: savesPath.path) else {
            return nil
        }

        return savesPath
    }

    private var screenshotsDirectory: URL? {
        let screenshotsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)

        guard FileManager.default.fileExists(atPath: screenshotsPath.path) else {
            return nil
        }

        return screenshotsPath
    }

    private var logsDirectory: URL? {
        let logsPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)

        guard FileManager.default.fileExists(atPath: logsPath.path) else {
            return nil
        }

        return logsPath
    }

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

    /// Checks which save types are available on disk, performing I/O off the main thread.
    private func checkTypesAvailability() async {
        let name = gameName
        let (worlds, screenshots, _, litematica, logs) = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let profileDir = AppPaths.profileDirectory(gameName: name)
            let savesPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
            let screenshotsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)
            let logsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
            let serversDatURL = profileDir.appendingPathComponent("servers.dat")
            let schematicsDir = AppPaths.schematicsDirectory(gameName: name)

            var hasWorlds = false
            if fm.fileExists(atPath: savesPath.path) {
                do {
                    let contents = try fm.contentsOfDirectory(
                        at: savesPath,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles],
                    )
                    hasWorlds = contents.contains { url in
                        guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                              isDirectory == true else { return false }
                        return true
                    }
                } catch {
                    hasWorlds = false
                }
            }

            var hasScreenshots = false
            if fm.fileExists(atPath: screenshotsPath.path) {
                do {
                    let contents = try fm.contentsOfDirectory(
                        at: screenshotsPath,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles],
                    )
                    hasScreenshots = contents.contains { url in
                        guard let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                              isFile == true else { return false }
                        let ext = url.pathExtension.lowercased()
                        return ["png", "jpg", "jpeg"].contains(ext)
                    }
                } catch {
                    hasScreenshots = false
                }
            }

            var hasLitematicaFiles = false
            if fm.fileExists(atPath: schematicsDir.path) {
                do {
                    let contents = try fm.contentsOfDirectory(
                        at: schematicsDir,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles],
                    )
                    hasLitematicaFiles = contents.contains { url in
                        guard let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                              isFile == true else { return false }
                        return url.pathExtension.lowercased() == "litematic"
                    }
                } catch {
                    hasLitematicaFiles = false
                }
            }

            var hasLogs = false
            if fm.fileExists(atPath: logsPath.path) {
                do {
                    let contents = try fm.contentsOfDirectory(
                        at: logsPath,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles],
                    )
                    hasLogs = contents.contains { url in
                        guard let isFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                              isFile == true else { return false }
                        return url.pathExtension.lowercased() == "log"
                    }
                } catch {
                    hasLogs = false
                }
            }

            return (
                hasWorlds,
                hasScreenshots,
                fm.fileExists(atPath: serversDatURL.path),
                hasLitematicaFiles,
                hasLogs,
            )
        }.value
        hasWorldsType = worlds
        hasScreenshotsType = screenshots
        hasLitematicaType = litematica
        hasLogsType = logs
    }

    private func fetchData() async {
        await checkTypesAvailability()

        isLoading = true

        await withTaskGroup(of: Void.self) { group in
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

            group.addTask { [weak self] in
                await self?.loadServers()
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

    private func loadServers() async {
        isLoadingServers = true
        defer { isLoadingServers = false }

        do {
            servers = try await serverAddressService.loadServerAddresses(for: gameName)
        } catch {
            AppLog.game.error("加载服务器地址信息失败: \(error.localizedDescription)")
            servers = []
        }
    }

    private func loadLitematicaFiles() async {
        isLoadingLitematica = true
        defer { isLoadingLitematica = false }

        do {
            litematicaFiles = try await litematicaService.loadLitematicaFiles(for: gameName)
        } catch {
            AppLog.game.error("加载 Litematica 文件信息失败: \(error.localizedDescription)")
            litematicaFiles = []
        }
    }

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

        isLoadingWorlds = false
        isLoadingScreenshots = false
        isLoadingServers = false
        isLoadingLitematica = false
        isLoadingLogs = false

        hasWorldsType = false
        hasScreenshotsType = false
        hasLitematicaType = false
        hasLogsType = false
    }

    /// Loads world information from the saves directory off the main thread.
    nonisolated private static func loadWorldsFromDirectory(gameName: String) -> [WorldInfo] {
        let savesPath = AppPaths.profileDirectory(gameName: gameName)
            .appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: savesPath.path) else { return [] }
        do {
            let contents = try fm.contentsOfDirectory(
                at: savesPath,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles],
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
                        lastPlayed = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
                    }

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
                        if let ds = dataTag["difficulty_settings"] as? [String: Any],
                           let diffStr = ds["difficulty"] as? String {
                            return WorldNBTMapper.mapDifficultyString(diffStr)
                        }
                        return nil
                    }()

                    let version: String? = (dataTag["Version"] as? [String: Any])?["Name"] as? String
                    let hardcore: Bool = {
                        if let ds = dataTag["difficulty_settings"] as? [String: Any] {
                            return WorldNBTMapper.readBoolFlag(ds["hardcore"])
                        }
                        return WorldNBTMapper.readBoolFlag(dataTag["hardcore"])
                    }()
                    let cheats: Bool = WorldNBTMapper.readBoolFlag(dataTag["allowCommands"])

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
                            seed: seed,
                        ),
                    )
                } catch {
                    AppLog.game.error("解析 level.dat 失败 (\(worldName)): \(error.localizedDescription)")
                    loadedWorlds.append(WorldInfo(name: worldName, path: worldPath, lastPlayed: lastPlayed, gameMode: nil, difficulty: nil, version: nil, seed: nil))
                }
            }
            loadedWorlds.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            return loadedWorlds
        } catch {
            AppLog.game.error("加载世界信息失败: \(error.localizedDescription)")
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
                options: [.skipsHiddenFiles],
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
            AppLog.game.error("加载截图信息失败: \(error.localizedDescription)")
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
                options: [.skipsHiddenFiles],
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
            AppLog.game.error("加载日志信息失败: \(error.localizedDescription)")
            return []
        }
    }
}
