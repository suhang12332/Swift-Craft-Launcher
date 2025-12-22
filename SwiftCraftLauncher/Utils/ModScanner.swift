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

        if let cached = AppCacheManager.shared.get(
            namespace: "mod",
            key: hash,
            as: ModrinthProjectDetail.self
        ) {
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

    // 新增：外部调用缓存写入
    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        AppCacheManager.shared.setSilently(
            namespace: "mod",
            key: hash,
            value: detail
        )
    }

    // MARK: - Hash

    /// 计算文件 SHA1 哈希值（静默版本）
    static func sha1Hash(of url: URL) -> String? {
        return SHA1Calculator.sha1Silent(ofFileAt: url)
    }

    /// 计算文件 SHA1 哈希值（抛出异常版本）
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

    /// 检查 mod 是否已安装（核心逻辑）
    private func checkModInstalledCore(
        slug: String,
        gameName: String
    ) async -> Bool {
        let cachedMods = await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
        return cachedMods.contains(slug)
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
                var detail = AppCacheManager.shared.get(
                    namespace: "mod",
                    key: hash,
                    as: ModrinthProjectDetail.self
                )

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

    /// 异步扫描：仅获取所有 slug（抛出异常版本）
    /// 在后台线程执行，只从缓存读取，不创建 fallback
    /// 返回 Set 以提高查找性能（O(1)）
    public func scanAllDetailIdsThrowing(in dir: URL) async throws -> Set<String> {
        // 如果是 mods 目录，优先返回缓存
        if isModsDirectory(dir) {
            if let gameName = extractGameName(from: dir) {
                let cachedMods = await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
                // 如果缓存不为空，直接返回缓存
                if !cachedMods.isEmpty {
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

                        // 只从缓存读取，不创建 fallback
                        let detail = AppCacheManager.shared.get(
                            namespace: "mod",
                            key: hash,
                            as: ModrinthProjectDetail.self
                        )

                        // 优先使用缓存的 slug，否则使用 hash
                        return detail?.slug ?? hash
                    }
                }

                var slugs: Set<String> = []
                for await slug in group {
                    if let slug = slug {
                        slugs.insert(slug)
                    }
                }

                // 如果是 mods 目录，自动缓存结果
                if self.isModsDirectory(dir) {
                    if let gameName = self.extractGameName(from: dir) {
                        await ModInstallationCache.shared.setAllModsInstalled(
                            for: gameName,
                            slugs: slugs
                        )
                    }
                }

                return slugs
            }
        }.value
    }

    /// 扫描单个游戏的 mods 目录（异步版本）
    /// - Parameter game: 要扫描的游戏
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

    /// 扫描单个游戏的 mods 目录（同步阻塞版本）
    /// - Parameter game: 要扫描的游戏
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

    /// 判断目录是否是 mods 目录
    /// - Parameter dir: 目录 URL
    /// - Returns: 是否是 mods 目录
    private func isModsDirectory(_ dir: URL) -> Bool {
        return dir.lastPathComponent.lowercased() == "mods"
    }

    /// 从 mods 目录路径中提取游戏名称
    /// - Parameter modsDir: mods 目录 URL
    /// - Returns: 游戏名称，如果无法提取则返回 nil
    private func extractGameName(from modsDir: URL) -> String? {
        // mods 目录结构：profileRootDirectory/gameName/mods
        // 所以 gameName 是 mods 目录的父目录名称
        let parentDir = modsDir.deletingLastPathComponent()
        return parentDir.lastPathComponent
    }

    /// 同步：仅查缓存
    func isModInstalledSync(slug: String, in modsDir: URL) -> Bool {
        do {
            return try isModInstalledSyncThrowing(
                slug: slug,
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
        slug: String,
        in modsDir: URL
    ) throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        // 使用 DispatchSemaphore 在同步函数中等待异步结果
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        Task {
            result = await checkModInstalledCore(slug: slug, gameName: gameName)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// 异步：仅查缓存（静默版本）
    func isModInstalled(
        slug: String,
        in modsDir: URL,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            do {
                let result = try await isModInstalledThrowing(
                    slug: slug,
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
        slug: String,
        in modsDir: URL
    ) async throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        return await checkModInstalledCore(slug: slug, gameName: gameName)
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
    /// Mod 安装状态缓存管理器
    /// 用于管理 mod 的安装状态缓存（仅内存缓存）
    actor ModInstallationCache {
        static let shared = ModInstallationCache()

        /// 内存缓存：gameName -> Set<slug>
        private var cache: [String: Set<String>] = [:]

        private init() {}

        /// 添加 slug 到缓存
        /// - Parameters:
        ///   - slug: 要添加的 slug
        ///   - gameName: 游戏名称
        func addSlug(_ slug: String, to gameName: String) {
            if var cached = cache[gameName] {
                cached.insert(slug)
                cache[gameName] = cached
            } else {
                // 如果缓存不存在，创建一个新的集合
                cache[gameName] = [slug]
            }
        }

        /// 从缓存中删除指定的 slug
        /// - Parameters:
        ///   - slug: 要删除的 slug
        ///   - gameName: 游戏名称
        func removeSlug(_ slug: String, from gameName: String) {
            if var cached = cache[gameName] {
                cached.remove(slug)
                cache[gameName] = cached
            }
        }

        /// 查询指定游戏的所有已安装 mod slug 集合
        /// - Parameter gameName: 游戏名称
        /// - Returns: 已安装的 mod slug 集合，如果不存在则返回空集合
        func getAllModsInstalled(for gameName: String) -> Set<String> {
            return cache[gameName] ?? Set<String>()
        }

        /// 批量设置指定游戏的所有已安装 mod slug 集合
        /// - Parameters:
        ///   - gameName: 游戏名称
        ///   - slugs: 要设置的 slug 集合
        func setAllModsInstalled(for gameName: String, slugs: Set<String>) {
            cache[gameName] = slugs
        }
    }

    /// 添加 slug 到缓存
    /// - Parameters:
    ///   - slug: 要添加的 slug
    ///   - gameName: 游戏名称
    func addModSlug(_ slug: String, to gameName: String) {
        Task {
            await ModInstallationCache.shared.addSlug(slug, to: gameName)
        }
    }

    /// 从缓存中删除指定的 slug
    /// - Parameters:
    ///   - slug: 要删除的 slug
    ///   - gameName: 游戏名称
    func removeModSlug(_ slug: String, from gameName: String) {
        Task {
            await ModInstallationCache.shared.removeSlug(slug, from: gameName)
        }
    }

    /// 查询指定游戏的所有已安装 mod slug 集合
    /// - Parameter gameName: 游戏名称
    /// - Returns: 已安装的 mod slug 集合，如果不存在则返回空集合
    func getAllModsInstalled(for gameName: String) async -> Set<String> {
        return await ModInstallationCache.shared.getAllModsInstalled(for: gameName)
    }
}
