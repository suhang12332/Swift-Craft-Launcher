//
//  ModScanner+DirectoryHash.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Directory hash scanning and FSEvents watcher management for mod directories.
extension ModScanner {
    /// Reads the directory and returns all jar and zip files.
    func readJarZipFiles(from dir: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw GlobalError.resource(
                chineseMessage: "目录不存在: \(dir.lastPathComponent)",
                i18nKey: "error.resource.directory_not_found",
                level: .silent,
            )
        }

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
            )
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage:
                    "读取目录失败: \(dir.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent,
            )
        }

        return files.filter {
            ["jar", "zip", "disable"].contains($0.pathExtension.lowercased())
        }
    }

    /// Rebuilds the hash set for a directory, updating both the general cache and the mod installation cache when applicable.
    func rebuildDirectoryHashes(
        dir: URL,
        gameNameHint: String? = nil,
    ) async throws -> Set<String> {
        let standardizedDir = dir.standardizedFileURL
        let jarFiles = try readJarZipFiles(from: standardizedDir)

        let concurrentCount = AppServices.generalSettingsManager.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)

        let hashes: Set<String> = await withTaskGroup(of: String?.self) { group in
            for fileURL in jarFiles {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    guard let hash = self.sha1Hash(of: fileURL) else {
                        return nil
                    }
                    return hash
                }
            }

            var result: Set<String> = []
            for await hash in group {
                if let hash {
                    result.insert(hash)
                }
            }
            return result
        }

        await AppServices.directoryHashCache.set(hashes, for: standardizedDir)

        if isModsDirectory(standardizedDir) {
            let gameName = gameNameHint ?? extractGameName(from: standardizedDir)
            if let gameName {
                await AppServices.modInstallationCache.setAllModsInstalled(
                    for: gameName,
                    hashes: hashes,
                )
            }
        }

        return hashes
    }

    /// Ensures the FSEvents watcher is registered for the given directory.
    func ensureFSEventsWatcherRegistered(
        standardizedDirectory: URL,
        gameNameHint: String?,
    ) async {
        let hint: String? = {
            if let gameNameHint { return gameNameHint }
            guard isModsDirectory(standardizedDirectory) else { return nil }
            return extractGameName(from: standardizedDirectory)
        }()
        await AppServices.modDirectoryWatcherRegistry.ensureWatching(
            directoryURL: standardizedDirectory,
            gameNameHint: hint,
        )
    }

    /// Returns cached detail IDs or performs a full scan if no cache exists.
    func scanAllDetailIdsAfterWatcherRegisteredThrowing(
        standardizedDirectory: URL,
    ) async throws -> Set<String> {
        if let cached = await AppServices.directoryHashCache.get(for: standardizedDirectory) {
            return cached
        }
        return try await rebuildDirectoryHashes(dir: standardizedDirectory)
    }

    /// Scans the directory for all detail IDs, returning the result via a completion handler.
    public func scanAllDetailIds(
        in dir: URL,
        completion: @escaping (Set<String>) -> Void,
    ) {
        Task {
            do {
                let detailIds = try await scanAllDetailIdsThrowing(in: dir)
                completion(detailIds)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描所有 detailId 失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
                completion(Set<String>())
            }
        }
    }

    /// Scans the directory for all detail IDs, returning a set for O(1) lookups.
    public func scanAllDetailIdsThrowing(in dir: URL) async throws -> Set<String> {
        let standardizedDir = dir.standardizedFileURL
        await ensureFSEventsWatcherRegistered(
            standardizedDirectory: standardizedDir,
            gameNameHint: nil,
        )
        return try await scanAllDetailIdsAfterWatcherRegisteredThrowing(
            standardizedDirectory: standardizedDir,
        )
    }

    /// Scans the mods directory for the given game in the background.
    public func scanGameModsDirectory(game: GameVersionInfo) async {
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)

        guard FileManager.default.fileExists(atPath: modsDir.path) else {
            Logger.shared.debug("游戏 \(game.gameName) 的 mods 目录不存在，跳过扫描")
            return
        }

        let standardizedModsDir = modsDir.standardizedFileURL
        await ensureFSEventsWatcherRegistered(
            standardizedDirectory: standardizedModsDir,
            gameNameHint: game.gameName,
        )

        do {
            let detailIds = try await scanAllDetailIdsAfterWatcherRegisteredThrowing(
                standardizedDirectory: standardizedModsDir,
            )
            Logger.shared.debug("游戏 \(game.gameName) 扫描完成，发现 \(detailIds.count) 个 mod")
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.warning("扫描游戏 \(game.gameName) 的 mods 目录失败: \(globalError.chineseMessage)")
        }
    }

    /// Synchronously scans the mods directory for the given game, blocking until complete.
    public func scanGameModsDirectorySync(game: GameVersionInfo) {
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)

        guard FileManager.default.fileExists(atPath: modsDir.path) else {
            Logger.shared.debug("游戏 \(game.gameName) 的 mods 目录不存在，跳过扫描")
            return
        }

        let standardizedModsDir = modsDir.standardizedFileURL
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            defer { semaphore.signal() }
            await self.ensureFSEventsWatcherRegistered(
                standardizedDirectory: standardizedModsDir,
                gameNameHint: game.gameName,
            )
            do {
                let detailIds = try await self.scanAllDetailIdsAfterWatcherRegisteredThrowing(
                    standardizedDirectory: standardizedModsDir,
                )
                Logger.shared.debug("游戏 \(game.gameName) 扫描完成，发现 \(detailIds.count) 个 mod")
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.warning("扫描游戏 \(game.gameName) 的 mods 目录失败: \(globalError.chineseMessage)")
            }
        }
        semaphore.wait()
    }

    /// Returns `true` if the directory is a mods directory.
    func isModsDirectory(_ dir: URL) -> Bool {
        dir.lastPathComponent.lowercased() == "mods"
    }

    /// Extracts the game name from a mods directory path.
    func extractGameName(from modsDir: URL) -> String? {
        let parentDir = modsDir.deletingLastPathComponent()
        return parentDir.lastPathComponent
    }
}
