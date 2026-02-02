import CryptoKit
import Foundation

class ModScanner {
    static let shared = ModScanner()

    private init() {}

    /// 主入口：获取 ModrinthProjectDetail（静默版本）
    func getModrinthProjectDetail(
        for fileURL: URL,
        completion: @escaping (ModrinthProjectDetail?) -> Void
    ) {
        Task {
            do {
                let detail = try await getModrinthProjectDetailThrowing(
                    for: fileURL
                )
                completion(detail)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(
                    "获取 Modrinth 项目详情失败: \(globalError.chineseMessage)"
                )
                GlobalErrorHandler.shared.handle(globalError)
                completion(nil)
            }
        }
    }

    /// 主入口：获取 ModrinthProjectDetail（抛出异常版本）
    func getModrinthProjectDetailThrowing(
        for fileURL: URL
    ) async throws -> ModrinthProjectDetail? {
        guard let hash = try Self.sha1HashThrowing(of: fileURL) else {
            throw GlobalError.validation(
                chineseMessage: "无法计算文件哈希值",
                i18nKey: "error.validation.file_hash_calculation_failed",
                level: .silent
            )
        }

        if let cached = getModCacheFromDatabase(hash: hash) {
            // 更新文件名为当前实际文件名（可能已重命名为 .disabled）
            var updatedCached = cached
            updatedCached.fileName = fileURL.lastPathComponent
            return updatedCached
        }

        // 使用 fetchModrinthDetail 通过文件 hash 查询
        let detail = await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                continuation.resume(returning: detail)
            }
        }

        if let detail = detail {
            // 设置本地文件名
            var detailWithFileName = detail
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        } else {
            // 尝试本地解析
            let (modid, version) =
                try ModMetadataParser.parseModMetadataThrowing(fileURL: fileURL)

            // 如果 CF 查询失败或没有解析到 modid，则回退到本地兜底逻辑
            if let modid = modid, let version = version {
                // 使用解析到的元数据创建兜底对象
                let fallbackDetail = createFallbackDetail(
                    fileURL: fileURL,
                    modid: modid,
                    version: version
                )
                saveToCache(hash: hash, detail: fallbackDetail)
                return fallbackDetail
            } else {
                // 最终兜底策略：使用文件名创建基础信息
                let fallbackDetail = createFallbackDetailFromFileName(
                    fileURL: fileURL
                )
                saveToCache(hash: hash, detail: fallbackDetail)
                return fallbackDetail
            }
        }
    }

    // MARK: - Mod Cache (Database)

    private func getModCacheFromDatabase(hash: String) -> ModrinthProjectDetail? {
        guard let jsonData = ModCacheManager.shared.get(hash: hash) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ModrinthProjectDetail.self, from: jsonData)
        } catch {
            Logger.shared.error("解码 mod 缓存失败: \(error.localizedDescription)")
            return nil
        }
    }

    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        do {
            let jsonData = try JSONEncoder().encode(detail)
            ModCacheManager.shared.setSilently(hash: hash, jsonData: jsonData)
        } catch {
            Logger.shared.error("编码 mod 缓存失败: \(error.localizedDescription)")
            GlobalErrorHandler.shared.handle(GlobalError.validation(
                chineseMessage: "保存 mod 缓存失败: \(error.localizedDescription)",
                i18nKey: "error.validation.mod_cache_encode_failed",
                level: .silent
            ))
        }
    }

    // MARK: - Hash

    static func sha1Hash(of url: URL) -> String? {
        return SHA1Calculator.sha1Silent(ofFileAt: url)
    }

    static func sha1HashThrowing(of url: URL) throws -> String? {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }

    // MARK: - Fallback Methods

    /// 兜底 ModrinthProjectDetail 的公共字段结构体
    private struct CommonFallbackFields {
        let description: String
        let categories: [String]
        let clientSide: String
        let serverSide: String
        let body: String
        let additionalCategories: [String]?
        let issuesUrl: String?
        let sourceUrl: String?
        let wikiUrl: String?
        let discordUrl: String?
        let projectType: String
        let downloads: Int
        let iconUrl: String?
        let team: String
        let published: Date
        let updated: Date
        let followers: Int
        let license: License?
        let gameVersions: [String]
        let loaders: [String]
        let type: String?
    }

    /// 创建基础 ModrinthProjectDetail 的公共字段
    private func createBaseFallbackDetail(fileURL: URL) -> (fileName: String, baseFileName: String) {
        let fileName = fileURL.lastPathComponent
        let baseFileName = fileName.replacingOccurrences(
            of: ".\(fileURL.pathExtension)",
            with: ""
        )
        return (fileName, baseFileName)
    }

    /// 创建兜底 ModrinthProjectDetail 的公共部分
    private func createCommonFallbackFields(fileName: String, baseFileName: String) -> CommonFallbackFields {
        return CommonFallbackFields(
            description: "local：\(fileName)",
            categories: ["unknown"],
            clientSide: "optional",
            serverSide: "optional",
            body: "",
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: "mod",
            downloads: 0,
            iconUrl: nil,
            team: "local",
            published: Date(),
            updated: Date(),
            followers: 0,
            license: nil,
            gameVersions: [],
            loaders: [],
            type: nil
        )
    }

    /// 使用解析到的元数据创建兜底 ModrinthProjectDetail
    private func createFallbackDetail(
        fileURL: URL,
        modid: String,
        version: String
    ) -> ModrinthProjectDetail {
        let (fileName, baseFileName) = createBaseFallbackDetail(fileURL: fileURL)
        let common = createCommonFallbackFields(fileName: fileName, baseFileName: baseFileName)

        return ModrinthProjectDetail(
            slug: modid,
            title: baseFileName,
            description: common.description,
            categories: common.categories,
            clientSide: common.clientSide,
            serverSide: common.serverSide,
            body: common.body,
            additionalCategories: common.additionalCategories,
            issuesUrl: common.issuesUrl,
            sourceUrl: common.sourceUrl,
            wikiUrl: common.wikiUrl,
            discordUrl: common.discordUrl,
            projectType: common.projectType,
            downloads: common.downloads,
            iconUrl: common.iconUrl,
            id: "local_\(modid)_\(UUID().uuidString.prefix(8))",
            team: common.team,
            published: common.published,
            updated: common.updated,
            followers: common.followers,
            license: common.license,
            versions: [version],
            gameVersions: common.gameVersions,
            loaders: common.loaders,
            type: common.type,
            fileName: fileName
        )
    }

    /// 使用文件名创建最基础的兜底 ModrinthProjectDetail
    private func createFallbackDetailFromFileName(
        fileURL: URL
    ) -> ModrinthProjectDetail {
        let (fileName, baseFileName) = createBaseFallbackDetail(fileURL: fileURL)
        let common = createCommonFallbackFields(fileName: fileName, baseFileName: baseFileName)

        return ModrinthProjectDetail(
            slug: baseFileName.lowercased().replacingOccurrences(
                of: " ",
                with: "-"
            ),
            title: baseFileName,
            description: common.description,
            categories: common.categories,
            clientSide: common.clientSide,
            serverSide: common.serverSide,
            body: common.body,
            additionalCategories: common.additionalCategories,
            issuesUrl: common.issuesUrl,
            sourceUrl: common.sourceUrl,
            wikiUrl: common.wikiUrl,
            discordUrl: common.discordUrl,
            projectType: common.projectType,
            downloads: common.downloads,
            iconUrl: common.iconUrl,
            id: "file_\(baseFileName)_\(UUID().uuidString.prefix(8))",
            team: common.team,
            published: common.published,
            updated: common.updated,
            followers: common.followers,
            license: common.license,
            versions: ["unknown"],
            gameVersions: common.gameVersions,
            loaders: common.loaders,
            type: common.type,
            fileName: fileName
        )
    }
}

extension ModScanner {
    // MARK: - 公共辅助方法

    /// 读取目录并过滤 jar/zip 文件（抛出异常版本）
    private func readJarZipFiles(from dir: URL) throws -> [URL] {
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

    /// 读取目录并过滤 jar/zip 文件（静默版本，目录不存在时返回空数组）
    private func readJarZipFilesSilent(from dir: URL) -> [URL] {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            )
            return files.filter {
                ["jar", "zip", "disable"].contains($0.pathExtension.lowercased())
            }
        } catch {
            return []
        }
    }

    /// 检查 mod 是否已安装
    private func checkModInstalledCore(
        hash: String,
        gameName: String
    ) async -> Bool {
        let cachedMods = await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
        return cachedMods.contains(hash)
    }

    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（静默版本）
    public func localModDetails(in dir: URL) -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        do {
            return try localModDetailsThrowing(in: dir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取本地 mod 详情失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（抛出异常版本）
    public func localModDetailsThrowing(in dir: URL) throws -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        let jarFiles = try readJarZipFiles(from: dir)
        return jarFiles.compactMap { fileURL in
            if let hash = ModScanner.sha1Hash(of: fileURL) {
                var detail = getModCacheFromDatabase(hash: hash)

                // 如果缓存中没有找到，使用兜底策略创建基础信息
                if detail == nil {
                    detail = createFallbackDetailFromFileName(fileURL: fileURL)
                    // 保存兜底信息到缓存，避免重复创建
                    if let detail = detail {
                        saveToCache(hash: hash, detail: detail)
                    }
                } else {
                    // 更新文件名为当前实际文件名（可能已重命名为 .disabled）
                    detail?.fileName = fileURL.lastPathComponent
                }

                return (file: fileURL, hash: hash, detail: detail)
            }
            return nil
        }
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
                GlobalErrorHandler.shared.handle(globalError)
                completion(Set<String>())
            }
        }
    }

    // 返回 Set 以提高查找性能（O(1)）
    public func scanAllDetailIdsThrowing(in dir: URL) async throws -> Set<String> {
        // 如果是 mods 目录，优先返回缓存
        if isModsDirectory(dir) {
            if let gameName = extractGameName(from: dir) {
                // 检查缓存是否存在（即使为空也返回缓存）
                let hasCache = await ModInstallationCache.shared.hasCache(for: gameName)
                if hasCache {
                    let cachedMods = await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
                    return cachedMods
                }
            }
        }

        // 在后台线程执行文件系统操作
        return try await Task.detached(priority: .userInitiated) {
            let jarFiles = try self.readJarZipFiles(from: dir)

            // 使用 TaskGroup 并发计算 hash 和读取缓存
            let concurrentCount = GeneralSettingsManager.shared.concurrentDownloads
            let semaphore = AsyncSemaphore(value: concurrentCount)

            return await withTaskGroup(of: String?.self) { group in
                for fileURL in jarFiles {
                    group.addTask {
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        guard let hash = ModScanner.sha1Hash(of: fileURL) else {
                            return nil
                        }

                        // 直接返回 hash，不再使用 slug
                        return hash
                    }
                }

                var hashes: Set<String> = []
                for await hash in group {
                    if let hash = hash {
                        hashes.insert(hash)
                    }
                }

                // 如果是 mods 目录，自动缓存结果
                if self.isModsDirectory(dir) {
                    if let gameName = self.extractGameName(from: dir) {
                        await ModInstallationCache.shared.setAllModsInstalled(
                            for: gameName,
                            hashes: hashes
                        )
                    }
                }

                return hashes
            }
        }.value
    }

    public func scanGameModsDirectory(game: GameVersionInfo) async {
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)

        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: modsDir.path) else {
            Logger.shared.debug("游戏 \(game.gameName) 的 mods 目录不存在，跳过扫描")
            return
        }

        do {
            let detailIds = try await scanAllDetailIdsThrowing(in: modsDir)
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

        // 使用 Task 同步等待异步操作完成
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            defer { semaphore.signal() }
            do {
                let detailIds = try await scanAllDetailIdsThrowing(in: modsDir)
                Logger.shared.debug("游戏 \(game.gameName) 扫描完成，发现 \(detailIds.count) 个 mod")
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.warning("扫描游戏 \(game.gameName) 的 mods 目录失败: \(globalError.chineseMessage)")
                // 不显示错误通知，因为这是后台扫描
            }
        }
        semaphore.wait()
    }

    private func isModsDirectory(_ dir: URL) -> Bool {
        return dir.lastPathComponent.lowercased() == "mods"
    }

    // mods 目录结构：profileRootDirectory/gameName/mods
    private func extractGameName(from modsDir: URL) -> String? {
        let parentDir = modsDir.deletingLastPathComponent()
        return parentDir.lastPathComponent
    }

    /// 同步：仅查缓存（通过文件hash检查）
    func isModInstalledSync(hash: String, in modsDir: URL) -> Bool {
        do {
            return try isModInstalledSyncThrowing(
                hash: hash,
                in: modsDir
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查 mod 安装状态失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 同步：仅查缓存（抛出异常版本）
    func isModInstalledSyncThrowing(
        hash: String,
        in modsDir: URL
    ) throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        // 使用 DispatchSemaphore 在同步函数中等待异步结果
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        Task {
            result = await checkModInstalledCore(hash: hash, gameName: gameName)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// 异步：仅查缓存（静默版本）
    func isModInstalled(
        hash: String,
        in modsDir: URL,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            do {
                let result = try await isModInstalledThrowing(
                    hash: hash,
                    in: modsDir
                )
                completion(result)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(
                    "检查 mod 安装状态失败: \(globalError.chineseMessage)"
                )
                GlobalErrorHandler.shared.handle(globalError)
                completion(false)
            }
        }
    }

    /// 异步：仅查缓存（抛出异常版本）
    func isModInstalledThrowing(
        hash: String,
        in modsDir: URL
    ) async throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        return await checkModInstalledCore(hash: hash, gameName: gameName)
    }

    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（静默版本）
    func scanResourceDirectory(
        _ dir: URL,
        completion: @escaping ([ModrinthProjectDetail]) -> Void
    ) {
        Task {
            do {
                let results = try await scanResourceDirectoryThrowing(dir)
                completion(results)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描资源目录失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion([])
            }
        }
    }

    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（抛出异常版本）
    func scanResourceDirectoryThrowing(
        _ dir: URL
    ) async throws -> [ModrinthProjectDetail] {
        let jarFiles = try readJarZipFiles(from: dir)
        if jarFiles.isEmpty {
            return []
        }

        // 创建信号量控制并发数量
        let concurrentCount = GeneralSettingsManager.shared.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)

        // 使用 TaskGroup 并发扫描文件
        let results = await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
            for fileURL in jarFiles {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    return try? await self.getModrinthProjectDetailThrowing(
                        for: fileURL
                    )
                }
            }

            // 收集结果
            var results: [ModrinthProjectDetail] = []
            for await result in group {
                if let detail = result {
                    results.append(detail)
                }
            }
            return results
        }

        return results
    }

    // MARK: - 分页扫描

    /// 计算分页范围
    private func calculatePageRange(
        totalCount: Int,
        page: Int,
        pageSize: Int
    ) -> (startIndex: Int, endIndex: Int, hasMore: Bool)? {
        guard totalCount > 0 else {
            return nil
        }

        let safePage = max(page, 1)
        let safePageSize = max(pageSize, 1)
        let startIndex = (safePage - 1) * safePageSize
        let endIndex = min(startIndex + safePageSize, totalCount)

        guard startIndex < totalCount else {
            return nil
        }

        return (startIndex, endIndex, endIndex < totalCount)
    }

    /// 并发扫描文件列表并返回详情
    private func scanFilesConcurrently(
        fileURLs: [URL],
        semaphore: AsyncSemaphore
    ) async -> [ModrinthProjectDetail] {
        await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    return try? await self.getModrinthProjectDetailThrowing(
                        for: fileURL
                    )
                }
            }

            var results: [ModrinthProjectDetail] = []
            for await result in group {
                if let detail = result {
                    results.append(detail)
                }
            }
            return results
        }
    }

    /// 获取目录下所有 jar/zip 文件列表（不解析详情，快速）
    func getAllResourceFiles(_ dir: URL) -> [URL] {
        do {
            return try getAllResourceFilesThrowing(dir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取资源文件列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取目录下所有 jar/zip 文件列表（抛出异常版本）
    func getAllResourceFilesThrowing(_ dir: URL) throws -> [URL] {
        // 目录不存在时返回空数组（不抛出异常，因为这是正常情况）
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }

        return try readJarZipFiles(from: dir)
    }

    /// 分页扫描目录，仅对当前页的文件进行解析（静默版本）
    func scanResourceDirectoryPage(
        _ dir: URL,
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceDirectoryPageThrowing(
                    dir,
                    page: page,
                    pageSize: pageSize
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("分页扫描资源目录失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion([], false)
            }
        }
    }

    /// 基于文件列表分页扫描，仅对当前页的文件进行解析（静默版本）
    func scanResourceFilesPage(
        fileURLs: [URL],
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceFilesPageThrowing(
                    fileURLs: fileURLs,
                    page: page,
                    pageSize: pageSize
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("分页扫描资源文件失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion([], false)
            }
        }
    }

    /// 基于文件列表分页扫描，仅对当前页的文件进行解析（抛出异常版本）
    func scanResourceFilesPageThrowing(
        fileURLs: [URL],
        page: Int,
        pageSize: Int
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        guard let pageRange = calculatePageRange(
            totalCount: fileURLs.count,
            page: page,
            pageSize: pageSize
        ) else {
            return ([], false)
        }

        let pageFiles = Array(fileURLs[pageRange.startIndex..<pageRange.endIndex])
        let concurrentCount = GeneralSettingsManager.shared.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)
        let results = await scanFilesConcurrently(fileURLs: pageFiles, semaphore: semaphore)

        return (results, pageRange.hasMore)
    }

    /// 分页扫描目录，仅对当前页的文件进行解析（抛出异常版本）
    func scanResourceDirectoryPageThrowing(
        _ dir: URL,
        page: Int,
        pageSize: Int
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        let jarFiles = try readJarZipFiles(from: dir)
        return try await scanResourceFilesPageThrowing(
            fileURLs: jarFiles,
            page: page,
            pageSize: pageSize
        )
    }
}

// MARK: - Mod Installation Cache
extension ModScanner {
    actor ModInstallationCache {
        static let shared = ModInstallationCache()

        private var cache: [String: Set<String>] = [:]

        private init() {}

        func addHash(_ hash: String, to gameName: String) {
            if var cached = cache[gameName] {
                cached.insert(hash)
                cache[gameName] = cached
            } else {
                // 如果缓存不存在，创建一个新的集合
                cache[gameName] = [hash]
            }
        }

        func removeHash(_ hash: String, from gameName: String) {
            if var cached = cache[gameName] {
                cached.remove(hash)
                cache[gameName] = cached
            }
        }

        func getAllModsInstalled(for gameName: String) -> Set<String> {
            return cache[gameName] ?? Set<String>()
        }

        func hasCache(for gameName: String) -> Bool {
            return cache[gameName] != nil
        }

        func setAllModsInstalled(for gameName: String, hashes: Set<String>) {
            cache[gameName] = hashes
        }

        func removeGame(gameName: String) {
            cache.removeValue(forKey: gameName)
        }
    }

    func addModHash(_ hash: String, to gameName: String) {
        Task {
            await ModInstallationCache.shared.addHash(hash, to: gameName)
        }
    }

    func removeModHash(_ hash: String, from gameName: String) {
        Task {
            await ModInstallationCache.shared.removeHash(hash, from: gameName)
        }
    }

    func getAllModsInstalled(for gameName: String) async -> Set<String> {
        return await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
    }

    func clearModCache(for gameName: String) async {
        await ModInstallationCache.shared.removeGame(gameName: gameName)
    }
}
