//
//  SaveInfoManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Loads and manages save information including worlds, screenshots,
/// litematica files, and logs for a specific game instance.
@MainActor
@Observable
final class SaveInfoManager {
    nonisolated private static func buildWorldInfo(worldPath: URL) -> WorldInfo {
        let worldName = worldPath.lastPathComponent
        let lastPlayed = (try? worldPath.resourceValues(
            forKeys: [.contentModificationDateKey],
        ))?.contentModificationDate
        return WorldInfo(name: worldName, path: worldPath, lastPlayed: lastPlayed)
    }

    let gameName: String
    let modLoader: String
    private(set) var worlds: [WorldInfo] = []
    private(set) var screenshots: [ScreenshotInfo] = []
    private(set) var litematicaFiles: [LitematicaInfo] = []
    private(set) var logs: [LogInfo] = []
    private(set) var isLoading: Bool = true

    private(set) var isLoadingWorlds: Bool = false
    private(set) var isLoadingScreenshots: Bool = false
    private(set) var isLoadingLitematica: Bool = false
    private(set) var isLoadingLogs: Bool = false

    /// Resource counts keyed by resource type (mod, datapack, resourcepack, shader, litematica, worlds, servers).
    private(set) var resourceCounts: [(type: String, count: Int, directory: URL?)] = []

    private(set) var hasWorldsType: Bool = false
    private(set) var hasScreenshotsType: Bool = false
    private(set) var hasLitematicaType: Bool = false
    private(set) var hasLogsType: Bool = false

    /// Load task handle.
    ///
    /// Load task handle.
    ///
    /// `@ObservationIgnored` — internal bookkeeping, not observable state. Accessible from
    /// the nonisolated `deinit` because `Task` is `Sendable`.
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    private var isVanilla: Bool {
        modLoader.lowercased() == GameLoader.vanilla.displayName
    }

    init(
        gameName: String,
        modLoader: String,
    ) {
        self.gameName = gameName
        self.modLoader = modLoader
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
        let (worlds, screenshots, logs) = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let profileDir = AppPaths.profileDirectory(gameName: name)
            let savesPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
            let screenshotsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)
            let logsPath = profileDir.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)

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
                hasLogs,
            )
        }.value
        hasWorldsType = worlds
        hasScreenshotsType = screenshots
        hasLogsType = logs
    }

    private func fetchData() async {
        await checkTypesAvailability()

        isLoading = true
        let vanilla = isVanilla

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
                await self?.loadResourceCounts()
            }

            if !vanilla {
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

        if vanilla {
            hasLitematicaType = false
            litematicaFiles = []
        } else {
            hasLitematicaType = !litematicaFiles.isEmpty
            let litematicaCount = litematicaFiles.count
            let schematicsDirectory = AppPaths.schematicsDirectory(gameName: gameName)
            let insertionIndex = resourceCounts.firstIndex { $0.type == "worlds" } ?? resourceCounts.endIndex
            resourceCounts.insert(
                (type: "litematica", count: litematicaCount, directory: schematicsDirectory),
                at: insertionIndex,
            )
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

    private func loadLitematicaFiles() async {
        isLoadingLitematica = true
        defer { isLoadingLitematica = false }

        do {
            litematicaFiles = try await DIContainer.shared.system.litematicaService.loadLitematicaFiles(for: gameName)
        } catch {
            AppLog.game.error("Failed to load Litematica file info: \(error.localizedDescription)")
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

    private func loadResourceCounts() async {
        let name = gameName
        let vanilla = isVanilla
        var counts: [(type: String, count: Int, directory: URL?)] = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let profileDir = AppPaths.profileDirectory(gameName: name)
            let allTypes: [(String, URL)] = [
                (ResourceType.mod.rawValue, AppPaths.modsDirectory(gameName: name)),
                (ResourceType.datapack.rawValue, AppPaths.datapacksDirectory(gameName: name)),
                (ResourceType.resourcepack.rawValue, AppPaths.resourcepacksDirectory(gameName: name)),
                (ResourceType.shader.rawValue, AppPaths.shaderpacksDirectory(gameName: name)),
                ("worlds", profileDir.appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)),
                ("screenshots", profileDir.appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)),
                ("logs", profileDir.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)),
            ]
            let hidden: Set<String> = vanilla ? [ResourceType.mod.rawValue, ResourceType.shader.rawValue] : []
            let types = allTypes.filter { !hidden.contains($0.0) }
            return types.map { type, url in
                (type: type, count: Self.countFiles(in: url, fm: fm), directory: url)
            }
        }.value

        if let servers = try? await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: name) {
            counts.append((type: "servers", count: servers.count, directory: nil))
        }
        resourceCounts = counts
    }

    nonisolated private static func countFiles(in directory: URL, fm: FileManager) -> Int {
        guard fm.fileExists(atPath: directory.path) else { return 0 }
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles],
        ) else { return 0 }
        return contents.count
    }

    private func resetData() {
        worlds.removeAll(keepingCapacity: false)
        screenshots.removeAll(keepingCapacity: false)
        litematicaFiles.removeAll(keepingCapacity: false)
        logs.removeAll(keepingCapacity: false)
        isLoading = false

        isLoadingWorlds = false
        isLoadingScreenshots = false
        isLoadingLitematica = false
        isLoadingLogs = false

        resourceCounts = []

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

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: savesPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles],
            )
        } catch {
            AppLog.game.error("Failed to load world info: \(error.localizedDescription)")
            return []
        }

        let loadedWorlds = contents.compactMap { worldPath -> WorldInfo? in
            guard let isDirectory = try? worldPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory == true else { return nil }
            return Self.buildWorldInfo(worldPath: worldPath)
        }

        return loadedWorlds.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
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
            AppLog.game.error("Failed to load screenshot info: \(error.localizedDescription)")
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
            loaded.sort {
                if $0.isCrashLog != $1.isCrashLog {
                    return $0.isCrashLog
                }
                return ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
            }
            return loaded
        } catch {
            AppLog.game.error("Failed to load log info: \(error.localizedDescription)")
            return []
        }
    }
}
