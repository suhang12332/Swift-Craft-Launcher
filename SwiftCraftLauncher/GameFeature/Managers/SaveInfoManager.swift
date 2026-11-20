//
//  SaveInfoManager.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Loads server addresses for a game; injectable for tests.
typealias ServerAddressLoader = @Sendable (_ gameName: String) async throws -> [ServerAddress]

/// Loads Litematica schematics for a game; injectable for tests.
typealias LitematicaLoader = @Sendable (_ gameName: String) async throws -> [LitematicaInfo]

/// An archive directory counted in the overview.
private struct ArchiveResource: Sendable {
    let kind: GameOverviewItem.Kind
    let directory: URL
    let isAvailableForVanilla: Bool
}

/// Loads and manages save information including worlds, screenshots,
/// litematica files, and logs for a specific game instance.
@MainActor
@Observable
final class SaveInfoManager {
    let gameName: String
    private(set) var worlds: [WorldInfo] = []
    private(set) var screenshots: [ScreenshotInfo] = []
    private(set) var litematicaFiles: [LitematicaInfo] = []
    private(set) var logs: [LogInfo] = []
    private(set) var isLoading: Bool = true

    private(set) var isLoadingWorlds: Bool = false
    private(set) var isLoadingScreenshots: Bool = false
    private(set) var isLoadingLitematica: Bool = false
    private(set) var isLoadingLogs: Bool = false

    /// Resource summaries displayed in the game overview.
    private(set) var resourceCounts: [GameOverviewItem] = []

    var hasWorldsType: Bool { !worlds.isEmpty }
    var hasScreenshotsType: Bool { !screenshots.isEmpty }
    var hasLitematicaType: Bool { !isVanilla && !litematicaFiles.isEmpty }
    var hasLogsType: Bool { !logs.isEmpty }

    /// Load task handle.
    ///
    /// `@ObservationIgnored` — internal bookkeeping, not observable state. Accessible from
    /// the nonisolated `deinit` because `Task` is `Sendable`.
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadGeneration = 0

    /// Base directory for this game profile. Injectable for tests.
    private let profileDirectory: URL
    private let serverAddressLoader: ServerAddressLoader
    private let litematicaLoader: LitematicaLoader
    private let isVanilla: Bool
    private let archiveResources: [ArchiveResource]
    @ObservationIgnored private var archiveCounts: [GameOverviewItem.Kind: Int] = [:]
    @ObservationIgnored private var failedKinds: Set<GameOverviewItem.Kind> = []
    @ObservationIgnored private var serverCount = 0

    init(
        gameName: String,
        modLoader: String,
        profileDirectory: URL? = nil,
        serverAddressLoader: @escaping ServerAddressLoader = { gameName in
            try await DIContainer.shared.system.serverAddressService.loadServerAddresses(for: gameName)
        },
        litematicaLoader: @escaping LitematicaLoader = { gameName in
            try await DIContainer.shared.system.litematicaService.loadLitematicaFiles(for: gameName)
        },
    ) {
        let rootDirectory = profileDirectory ?? AppPaths.profileDirectory(gameName: gameName)
        self.gameName = gameName
        self.profileDirectory = rootDirectory
        self.serverAddressLoader = serverAddressLoader
        self.litematicaLoader = litematicaLoader
        isVanilla = GameLoader(rawValue: modLoader.lowercased()) == .vanilla
        archiveResources = [
            ArchiveResource(
                kind: .mod,
                directory: rootDirectory.appendingPathComponent(ResourceType.mod.folderName, isDirectory: true),
                isAvailableForVanilla: false,
            ),
            ArchiveResource(
                kind: .datapack,
                directory: rootDirectory.appendingPathComponent(ResourceType.datapack.folderName, isDirectory: true),
                isAvailableForVanilla: true,
            ),
            ArchiveResource(
                kind: .resourcepack,
                directory: rootDirectory.appendingPathComponent(ResourceType.resourcepack.folderName, isDirectory: true),
                isAvailableForVanilla: true,
            ),
            ArchiveResource(
                kind: .shader,
                directory: rootDirectory.appendingPathComponent(ResourceType.shader.folderName, isDirectory: true),
                isAvailableForVanilla: false,
            ),
        ]
    }

    deinit {
        loadTask?.cancel()
    }

    private var activeArchiveResources: [ArchiveResource] {
        isVanilla ? archiveResources.filter(\.isAvailableForVanilla) : archiveResources
    }

    private var schematicsDirectory: URL {
        profileDirectory.appendingPathComponent(AppConstants.DirectoryNames.schematics, isDirectory: true)
    }

    private var savesDirectory: URL {
        profileDirectory.appendingPathComponent(AppConstants.DirectoryNames.saves, isDirectory: true)
    }

    private var screenshotsDirectory: URL {
        profileDirectory.appendingPathComponent(AppConstants.DirectoryNames.screenshots, isDirectory: true)
    }

    private var logsDirectory: URL {
        profileDirectory.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
    }

    private var crashReportsDirectory: URL {
        profileDirectory.appendingPathComponent(AppConstants.DirectoryNames.crashReports, isDirectory: true)
    }

    @discardableResult
    func loadData() -> Task<Void, Never> {
        loadTask?.cancel()
        loadGeneration &+= 1
        let generation = loadGeneration
        let task = Task { await fetchData(generation: generation) }
        loadTask = task
        return task
    }

    func clearCache() {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration &+= 1
        resetData()
    }

    private func fetchData(generation: Int) async {
        guard generation == loadGeneration, !Task.isCancelled else { return }

        isLoading = true
        failedKinds.removeAll()

        defer {
            if generation == loadGeneration {
                isLoading = false
                loadTask = nil
            }
        }

        let vanilla = isVanilla

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.loadWorlds(generation: generation)
            }

            group.addTask { [weak self] in
                await self?.loadScreenshots(generation: generation)
            }

            group.addTask { [weak self] in
                await self?.loadLogs(generation: generation)
            }

            group.addTask { [weak self] in
                await self?.loadArchiveCounts(generation: generation)
            }

            group.addTask { [weak self] in
                await self?.loadServerCount(generation: generation)
            }

            if !vanilla {
                group.addTask { [weak self] in
                    await self?.loadLitematicaFiles(generation: generation)
                }
            }
        }

        guard generation == loadGeneration, !Task.isCancelled else { return }

        rebuildResourceCounts()
    }

    private func loadWorlds(generation: Int) async {
        guard generation == loadGeneration else { return }
        isLoadingWorlds = true
        defer {
            if generation == loadGeneration {
                isLoadingWorlds = false
            }
        }

        let directory = savesDirectory
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadWorldsFromDirectory(savesDirectory: directory)
        }.value
        guard generation == loadGeneration, !Task.isCancelled else { return }
        worlds = result.items
        setLoadFailure(.world, result.failed)
    }

    private func loadScreenshots(generation: Int) async {
        guard generation == loadGeneration else { return }
        isLoadingScreenshots = true
        defer {
            if generation == loadGeneration {
                isLoadingScreenshots = false
            }
        }

        let directory = screenshotsDirectory
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadScreenshotsFromDirectory(screenshotsDirectory: directory)
        }.value
        guard generation == loadGeneration, !Task.isCancelled else { return }
        screenshots = result.items
        setLoadFailure(.screenshot, result.failed)
    }

    private func loadLitematicaFiles(generation: Int) async {
        guard generation == loadGeneration else { return }
        isLoadingLitematica = true
        defer {
            if generation == loadGeneration {
                isLoadingLitematica = false
            }
        }

        do {
            let loaded = try await litematicaLoader(gameName)
            guard generation == loadGeneration, !Task.isCancelled else { return }
            litematicaFiles = loaded
            setLoadFailure(.litematica, false)
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            AppLog.game.error("Failed to load Litematica file info: \(error.localizedDescription)")
            litematicaFiles = []
            setLoadFailure(.litematica, true)
        }
    }

    private func loadLogs(generation: Int) async {
        guard generation == loadGeneration else { return }
        isLoadingLogs = true
        defer {
            if generation == loadGeneration {
                isLoadingLogs = false
            }
        }

        let logsDir = logsDirectory
        let crashDir = crashReportsDirectory
        let result = await Task.detached(priority: .userInitiated) {
            Self.loadLogsFromDirectory(
                logsDirectory: logsDir,
                crashReportsDirectory: crashDir,
            )
        }.value
        guard generation == loadGeneration, !Task.isCancelled else { return }
        logs = result.items
        setLoadFailure(.log, result.failed)
    }

    private func loadArchiveCounts(generation: Int) async {
        guard generation == loadGeneration else { return }
        let resources = activeArchiveResources
        let result = await Task.detached(priority: .userInitiated) {
            Self.countArchives(in: resources)
        }.value
        guard generation == loadGeneration, !Task.isCancelled else { return }
        archiveCounts = result.counts
        for resource in resources {
            setLoadFailure(resource.kind, false)
        }
        for kind in result.failedKinds {
            setLoadFailure(kind, true)
        }
    }

    private func loadServerCount(generation: Int) async {
        guard generation == loadGeneration else { return }
        do {
            let count = try await serverAddressLoader(gameName).count
            guard generation == loadGeneration, !Task.isCancelled else { return }
            serverCount = count
            setLoadFailure(.server, false)
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            serverCount = 0
            setLoadFailure(.server, true)
            AppLog.game.error(
                "Failed to load server addresses for game \(gameName): \(error.localizedDescription)",
            )
        }
    }

    private func setLoadFailure(_ kind: GameOverviewItem.Kind, _ failed: Bool) {
        if failed {
            failedKinds.insert(kind)
        } else {
            failedKinds.remove(kind)
        }
    }

    private func rebuildResourceCounts() {
        var items = activeArchiveResources.map { resource in
            GameOverviewItem(
                kind: resource.kind,
                itemCount: archiveCounts[resource.kind] ?? 0,
                directories: [resource.directory],
                hasError: failedKinds.contains(resource.kind),
            )
        }

        if !isVanilla {
            items.append(GameOverviewItem(
                kind: .litematica,
                itemCount: litematicaFiles.count,
                directories: [schematicsDirectory],
                hasError: failedKinds.contains(.litematica),
            ))
        }
        items.append(GameOverviewItem(
            kind: .world,
            itemCount: worlds.count,
            directories: [savesDirectory],
            hasError: failedKinds.contains(.world),
        ))
        items.append(GameOverviewItem(
            kind: .screenshot,
            itemCount: screenshots.count,
            directories: [screenshotsDirectory],
            hasError: failedKinds.contains(.screenshot),
        ))
        items.append(GameOverviewItem(
            kind: .log,
            itemCount: logs.count,
            directories: [logsDirectory, crashReportsDirectory],
            hasError: failedKinds.contains(.log),
        ))
        items.append(GameOverviewItem(
            kind: .server,
            itemCount: serverCount,
            hasError: failedKinds.contains(.server),
        ))
        assert(
            Set(items.map(\.kind)).count == items.count,
            "Game overview contains duplicate kinds",
        )
        resourceCounts = items
    }

    /// Counts archive files using the same cached scan as the local resource list.
    nonisolated private static func countArchives(
        in resources: [ArchiveResource],
    ) -> (counts: [GameOverviewItem.Kind: Int], failedKinds: Set<GameOverviewItem.Kind>) {
        let scanner = DIContainer.shared.core.modScanner
        var counts: [GameOverviewItem.Kind: Int] = [:]
        var failedKinds: Set<GameOverviewItem.Kind> = []

        for resource in resources {
            do {
                counts[resource.kind] = try scanner.getAllResourceFilesThrowing(resource.directory).count
            } catch {
                AppLog.game.error(
                    "Failed to count archives in \(resource.directory.lastPathComponent): \(error.localizedDescription)",
                )
                counts[resource.kind] = 0
                failedKinds.insert(resource.kind)
            }
        }

        return (counts, failedKinds)
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
        archiveCounts = [:]
        failedKinds.removeAll()
        serverCount = 0
    }

    /// Reads a directory, treating a missing directory as empty and logging other failures.
    nonisolated private static func readDirectory(
        at directory: URL,
        includingPropertiesForKeys keys: Set<URLResourceKey>,
        errorContext: String,
    ) -> (contents: [URL], failed: Bool) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
            )
            return (contents, false)
        } catch {
            let nsError = error as NSError
            let isMissing = nsError.domain == NSCocoaErrorDomain
                && nsError.code == CocoaError.Code.fileReadNoSuchFile.rawValue
            if !isMissing {
                AppLog.game.error("Failed to load \(errorContext): \(error.localizedDescription)")
                return ([], true)
            }
            return ([], false)
        }
    }

    /// Loads world information from the saves directory off the main thread.
    nonisolated private static func loadWorldsFromDirectory(
        savesDirectory: URL,
    ) -> (items: [WorldInfo], failed: Bool) {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let directoryResult = readDirectory(
            at: savesDirectory,
            includingPropertiesForKeys: keys,
            errorContext: "world info",
        )
        var failed = directoryResult.failed

        let loadedWorlds = directoryResult.contents.compactMap { worldPath -> WorldInfo? in
            guard let values = try? worldPath.resourceValues(forKeys: keys) else {
                failed = true
                return nil
            }
            guard values.isDirectory == true else { return nil }
            return WorldInfo(
                name: worldPath.lastPathComponent,
                path: worldPath,
                lastPlayed: values.contentModificationDate,
            )
        }

        return (
            loadedWorlds.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) },
            failed,
        )
    }

    nonisolated private static func loadScreenshotsFromDirectory(
        screenshotsDirectory: URL,
    ) -> (items: [ScreenshotInfo], failed: Bool) {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .creationDateKey, .fileSizeKey]
        let directoryResult = readDirectory(
            at: screenshotsDirectory,
            includingPropertiesForKeys: keys,
            errorContext: "screenshot info",
        )
        var failed = directoryResult.failed

        let loaded = directoryResult.contents.compactMap { screenshotPath -> ScreenshotInfo? in
            guard let values = try? screenshotPath.resourceValues(forKeys: keys) else {
                failed = true
                return nil
            }
            guard values.isRegularFile == true else { return nil }
            let ext = screenshotPath.pathExtension.lowercased()
            guard ["png", "jpg", "jpeg"].contains(ext) else { return nil }
            return ScreenshotInfo(
                name: screenshotPath.lastPathComponent,
                path: screenshotPath,
                createdDate: values.creationDate,
                fileSize: Int64(values.fileSize ?? 0),
            )
        }

        return (
            loaded.sorted { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) },
            failed,
        )
    }

    /// Loads logs from `logs/` plus crash reports. Rotated `.log.gz` files are excluded.
    nonisolated private static func loadLogsFromDirectory(
        logsDirectory: URL,
        crashReportsDirectory: URL,
    ) -> (items: [LogInfo], failed: Bool) {
        let logsResult = loadLogEntries(
            in: logsDirectory,
            accepts: { $0.hasSuffix(".log") },
            forceCrashLog: false,
        )
        let crashReportsResult = loadLogEntries(
            in: crashReportsDirectory,
            accepts: { $0.hasSuffix(".txt") },
            forceCrashLog: true,
        )
        let loaded = logsResult.items + crashReportsResult.items

        return (
            loaded.sorted {
                if $0.isCrashLog != $1.isCrashLog {
                    return $0.isCrashLog
                }
                return ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
            },
            logsResult.failed || crashReportsResult.failed,
        )
    }

    nonisolated private static func loadLogEntries(
        in directory: URL,
        accepts: (String) -> Bool,
        forceCrashLog: Bool,
    ) -> (items: [LogInfo], failed: Bool) {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .creationDateKey, .fileSizeKey]
        let directoryResult = readDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            errorContext: "log info from \(directory.lastPathComponent)",
        )
        var failed = directoryResult.failed

        let loaded = directoryResult.contents.compactMap { logPath -> LogInfo? in
            let name = logPath.lastPathComponent
            let fileNameLower = name.lowercased()
            guard accepts(fileNameLower) else { return nil }
            guard let values = try? logPath.resourceValues(forKeys: keys) else {
                failed = true
                return nil
            }
            guard values.isRegularFile == true else { return nil }
            let isCrashLog = forceCrashLog
                || fileNameLower.contains("crash")
                || fileNameLower.contains("error")
                || fileNameLower.contains("exception")
            return LogInfo(
                name: name,
                path: logPath,
                createdDate: values.creationDate,
                fileSize: Int64(values.fileSize ?? 0),
                isCrashLog: isCrashLog,
            )
        }

        return (loaded, failed)
    }
}
