import Foundation

extension ModScanner {
    // MARK: - 目录 Hash 扫描

    /// 读取目录并过滤 jar/zip 文件（抛出异常版本）
    func readJarZipFiles(from dir: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw GlobalError.resource(
                chineseMessage: "目录不存在: \(dir.lastPathComponent)",
                i18nKey: "error.resource.directory_not_found",
                level: .silent
            )
        }

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage:
                    "读取目录失败: \(dir.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent
            )
        }

        return files.filter {
            ["jar", "zip", "disable"].contains($0.pathExtension.lowercased())
        }
    }

    /// 通用：重新扫描某个目录并更新 hash 缓存；如为 mods 目录则同步更新 ModInstallationCache
    func rebuildDirectoryHashes(
        dir: URL,
        gameNameHint: String? = nil
    ) async throws -> Set<String> {
        let standardizedDir = dir.standardizedFileURL
        let jarFiles = try readJarZipFiles(from: standardizedDir)

        // 使用 TaskGroup 并发计算 hash
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
                if let hash = hash {
                    result.insert(hash)
                }
            }
            return result
        }

        // 写入通用目录 hash 缓存
        await AppServices.directoryHashCache.set(hashes, for: standardizedDir)

        // 如果是 mods 目录，同步到 ModInstallationCache，供 isModInstalled* 使用
        if isModsDirectory(standardizedDir) {
            let gameName = gameNameHint ?? extractGameName(from: standardizedDir)
            if let gameName {
                await AppServices.modInstallationCache.setAllModsInstalled(
                    for: gameName,
                    hashes: hashes
                )
            }
        }

        return hashes
    }

    func ensureFSEventsWatcherRegistered(
        standardizedDirectory: URL,
        gameNameHint: String?
    ) async {
        let hint: String? = {
            if let gameNameHint { return gameNameHint }
            guard isModsDirectory(standardizedDirectory) else { return nil }
            return extractGameName(from: standardizedDirectory)
        }()
        await AppServices.modDirectoryWatcherRegistry.ensureWatching(
            directoryURL: standardizedDirectory,
            gameNameHint: hint
        )
    }

    func scanAllDetailIdsAfterWatcherRegisteredThrowing(
        standardizedDirectory: URL
    ) async throws -> Set<String> {
        if let cached = await AppServices.directoryHashCache.get(for: standardizedDirectory) {
            return cached
        }
        return try await rebuildDirectoryHashes(dir: standardizedDirectory)
    }

    /// 异步扫描：仅获取所有 detailId（静默版本）
    /// 在后台线程执行，只从缓存读取，不创建 fallback
    public func scanAllDetailIds(
        in dir: URL,
        completion: @escaping (Set<String>) -> Void
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

    // 返回 Set 以提高查找性能（O(1)）

    public func scanAllDetailIdsThrowing(in dir: URL) async throws -> Set<String> {
        let standardizedDir = dir.standardizedFileURL
        await ensureFSEventsWatcherRegistered(
            standardizedDirectory: standardizedDir,
            gameNameHint: nil
        )
        return try await scanAllDetailIdsAfterWatcherRegisteredThrowing(
            standardizedDirectory: standardizedDir
        )
    }

    public func scanGameModsDirectory(game: GameVersionInfo) async {
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)

        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: modsDir.path) else {
            Logger.shared.debug("游戏 \(game.gameName) 的 mods 目录不存在，跳过扫描")
            return
        }

        let standardizedModsDir = modsDir.standardizedFileURL
        await ensureFSEventsWatcherRegistered(
            standardizedDirectory: standardizedModsDir,
            gameNameHint: game.gameName
        )

        do {
            let detailIds = try await scanAllDetailIdsAfterWatcherRegisteredThrowing(
                standardizedDirectory: standardizedModsDir
            )
            Logger.shared.debug("游戏 \(game.gameName) 扫描完成，发现 \(detailIds.count) 个 mod")
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.warning("扫描游戏 \(game.gameName) 的 mods 目录失败: \(globalError.chineseMessage)")
            // 不显示错误通知，因为这是后台扫描
        }
    }

    public func scanGameModsDirectorySync(game: GameVersionInfo) {
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)

        // 检查目录是否存在
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
                gameNameHint: game.gameName
            )
            do {
                let detailIds = try await self.scanAllDetailIdsAfterWatcherRegisteredThrowing(
                    standardizedDirectory: standardizedModsDir
                )
                Logger.shared.debug("游戏 \(game.gameName) 扫描完成，发现 \(detailIds.count) 个 mod")
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.warning("扫描游戏 \(game.gameName) 的 mods 目录失败: \(globalError.chineseMessage)")
                // 不显示错误通知，因为这是后台扫描
            }
        }
        semaphore.wait()
    }

    func isModsDirectory(_ dir: URL) -> Bool {
        return dir.lastPathComponent.lowercased() == "mods"
    }

    // mods 目录结构：profileRootDirectory/gameName/mods
    func extractGameName(from modsDir: URL) -> String? {
        let parentDir = modsDir.deletingLastPathComponent()
        return parentDir.lastPathComponent
    }
}
