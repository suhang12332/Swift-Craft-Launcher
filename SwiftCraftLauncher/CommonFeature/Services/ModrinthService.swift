import Foundation

// MARK: - JSONDecoder Extension for Modrinth Date Handling
private extension JSONDecoder {
    /// Configures the decoder with Modrinth's custom date decoding strategy
    func configureForModrinth() {
        self.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = formatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(dateStr)"
            )
        }
    }
}

enum ModrinthService {

    static func fetchVersionInfo(from version: String) async throws -> MinecraftVersionManifest {
        let cacheKey = "version_info_\(version)"

        // 检查缓存
        if let cachedVersionInfo: MinecraftVersionManifest = AppCacheManager.shared.get(namespace: "version_info", key: cacheKey, as: MinecraftVersionManifest.self) {
            return cachedVersionInfo
        }

        // 从API获取版本信息
        let versionInfo = try await fetchVersionInfoThrowing(from: version)

        // 缓存整个版本信息
        AppCacheManager.shared.setSilently(
            namespace: "version_info",
            key: cacheKey,
            value: versionInfo
        )

        return versionInfo
    }

    static func queryVersionTime(from version: String) async -> String {
        let cacheKey = "version_time_\(version)"

        // 检查缓存
        if let cachedTime: String = AppCacheManager.shared.get(namespace: "version_time", key: cacheKey, as: String.self) {
            return cachedTime
        }

        do {
            // 使用缓存的版本信息，避免重复API调用
            let versionInfo = try await Self.fetchVersionInfo(from: version)
            let formattedTime = CommonUtil.formatRelativeTime(versionInfo.releaseTime)

            // 缓存版本时间信息
            AppCacheManager.shared.setSilently(
                namespace: "version_time",
                key: cacheKey,
                value: formattedTime
            )
            return formattedTime
        } catch {
            return ""
        }
    }

    static func fetchVersionInfoThrowing(from version: String) async throws -> MinecraftVersionManifest {
        let url = URLConfig.API.Modrinth.versionInfo(version: version)

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        do {
            let decoder = JSONDecoder()
            decoder.configureForModrinth()
            let versionInfo = try decoder.decode(MinecraftVersionManifest.self, from: data)
            return versionInfo
        } catch {
            if error is GlobalError {
                throw error
            } else {
                throw GlobalError.validation(
                    chineseMessage: "解析版本信息失败",
                    i18nKey: "error.validation.version_info_parse_failed",
                    level: .notification
                )
            }
        }
    }

    static func searchProjects(
        facets: [[String]]? = nil,
        offset: Int = 0,
        limit: Int,
        query: String?
    ) async -> ModrinthResult {
        do {
            return try await searchProjectsThrowing(
                facets: facets,
                index: AppConstants.modrinthIndex,
                offset: offset,
                limit: limit,
                query: query
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索 Modrinth 项目失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return ModrinthResult(hits: [], offset: offset, limit: limit, totalHits: 0)
        }
    }

    static func searchProjectsThrowing(
        facets: [[String]]? = nil,
        index: String,
        offset: Int = 0,
        limit: Int,
        query: String?
    ) async throws -> ModrinthResult {
        guard var components = URLComponents(
            url: URLConfig.API.Modrinth.search,
            resolvingAgainstBaseURL: true
        ) else {
            throw GlobalError.validation(
                chineseMessage: "构建URLComponents失败",
                i18nKey: "error.validation.url_components_build_failed",
                level: .notification
            )
        }
        var queryItems = [
            URLQueryItem(name: "index", value: index),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(min(limit, 100))),
        ]
        if let query = query {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        if let facets = facets {
            do {
                let facetsJson = try JSONEncoder().encode(facets)
                if let facetsString = String(data: facetsJson, encoding: .utf8) {
                    queryItems.append(
                        URLQueryItem(name: "facets", value: facetsString)
                    )
                }
            } catch {
                throw GlobalError.validation(
                    chineseMessage: "编码搜索条件失败: \(error.localizedDescription)",
                    i18nKey: "error.validation.search_condition_encode_failed",
                    level: .notification
                )
            }
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw GlobalError.validation(
                chineseMessage: "构建搜索URL失败",
                i18nKey: "error.validation.search_url_build_failed",
                level: .notification
            )
        }
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        let result = try decoder.decode(ModrinthResult.self, from: data)

        return result
    }

    static func fetchLoaders() async -> [Loader] {
        do {
            return try await fetchLoadersThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 加载器列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    static func fetchLoadersThrowing() async throws -> [Loader] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.loaderTag)
        let result = try JSONDecoder().decode([Loader].self, from: data)
        return result
    }

    static func fetchCategories() async -> [Category] {
        do {
            return try await fetchCategoriesThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 分类列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    static func fetchCategoriesThrowing() async throws -> [Category] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.categoryTag)
        let result = try JSONDecoder().decode([Category].self, from: data)
        return result
    }

    static func fetchGameVersions(includeSnapshots: Bool = false) async -> [GameVersion] {
        do {
            return try await fetchGameVersionsThrowing(includeSnapshots: includeSnapshots)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 游戏版本列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    static func fetchGameVersionsThrowing(
        includeSnapshots: Bool = false
    ) async throws -> [GameVersion] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.gameVersionTag)
        let result = try JSONDecoder().decode([GameVersion].self, from: data)
        // 默认仅返回正式版，如果 includeSnapshots 为 true，则返回所有版本
        return includeSnapshots ? result : result.filter { $0.version_type == "release" }
    }

    static func fetchProjectDetails(id: String, type: String = "") async -> ModrinthProjectDetail? {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return await CurseForgeService.fetchProjectDetailsAsModrinth(id: id)
        }

        if !type.isEmpty {
            guard let result = await fetchProjectDetailsV3(id: id) else { return nil }
            return ModrinthProjectDetail.fromV3(result)
        }
        // 使用 Modrinth 服务
        do {
            return try await fetchProjectDetailsThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    static func fetchProjectDetailsThrowing(id: String) async throws -> ModrinthProjectDetail {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return try await CurseForgeService.fetchProjectDetailsAsModrinthThrowing(id: id)
        }

        // 使用 Modrinth 服务
        let url = URLConfig.API.Modrinth.project(id: id)

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        var detail = try decoder.decode(ModrinthProjectDetail.self, from: data)

        // 仅保留纯数字（含点号）的正式版游戏版本，例如 1.20.4
        let releaseGameVersions = detail.gameVersions.filter {
            $0.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
        }
        let result = CommonUtil.sortMinecraftVersions(releaseGameVersions)
        detail.gameVersions = CommonUtil.versionsAtLeast(result)

        return detail
    }

    // MARK: - v3 服务器项目详情（包含服务器信息等新字段）
    static func fetchProjectDetailsV3(id: String) async -> ModrinthProjectDetailV3? {
        do {
            return try await fetchProjectDetailsV3Throwing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 v3 项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 抛出错误的 v3 项目详情获取方法
    static func fetchProjectDetailsV3Throwing(id: String) async throws -> ModrinthProjectDetailV3 {
        let url = URLConfig.API.Modrinth.projectV3(id: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailV3.self, from: data)
    }

    static func fetchProjectVersions(id: String) async -> [ModrinthProjectDetailVersion] {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return await CurseForgeService.fetchProjectVersionsAsModrinth(id: id)
        }

        do {
            return try await fetchProjectVersionsThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目版本列表失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    static func fetchProjectVersionsThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return try await CurseForgeService.fetchProjectVersionsAsModrinthThrowing(id: id)
        }

        let url = URLConfig.API.Modrinth.version(id: id)

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode([ModrinthProjectDetailVersion].self, from: data)
    }

    static func fetchProjectVersionsFilter(
            id: String,
            selectedVersions: [String],
            selectedLoaders: [String],
            type: String
        ) async throws -> [ModrinthProjectDetailVersion] {
            // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
            if id.hasPrefix("cf-") {
                return try await CurseForgeService.fetchProjectVersionsFilterAsModrinth(
                    id: id,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type
                )
            }

            let versions = try await fetchProjectVersionsThrowing(id: id)
            var loaders = selectedLoaders
            if type == ResourceType.datapack.rawValue {
                loaders = [ResourceType.datapack.rawValue]
            } else if type == ResourceType.resourcepack.rawValue {
                loaders = ["minecraft"]
            }
            return versions.filter { version in
                // 必须同时满足版本和 loader 匹配
                let versionMatch = selectedVersions.isEmpty || !Set(version.gameVersions).isDisjoint(with: selectedVersions)

                // 对于shader和resourcepack，不检查loader匹配
                let loaderMatch: Bool
                if type == ResourceType.shader.rawValue || type == ResourceType.resourcepack.rawValue {
                    loaderMatch = true
                } else {
                    loaderMatch = loaders.isEmpty || !Set(version.loaders).isDisjoint(with: loaders)
                }

                return versionMatch && loaderMatch
            }
        }

    static func fetchProjectDependencies(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String]
    ) async -> ModrinthProjectDependency {
        do {
            return try await fetchProjectDependenciesThrowing(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目依赖失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return ModrinthProjectDependency(projects: [])
        }
    }

    static func fetchProjectDependenciesThrowing(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String]
    ) async throws -> ModrinthProjectDependency {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return try await CurseForgeService.fetchProjectDependenciesThrowingAsModrinth(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders
            )
        }

        // 1. 获取所有筛选后的版本
        let versions = try await fetchProjectVersionsFilter(
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            type: type
        )
        // 只取第一个版本
        guard let firstVersion = versions.first else {
            return ModrinthProjectDependency(projects: [])
        }

        // 2. 并发获取所有依赖项目的兼容版本（使用批处理限制并发数量）
        let requiredDeps = firstVersion.dependencies.filter { $0.dependencyType == "required" && $0.projectId != nil }
        let maxConcurrentTasks = 10 // 限制最大并发任务数
        var allDependencyVersions: [ModrinthProjectDetailVersion] = []

        // 分批处理依赖，每批最多 maxConcurrentTasks 个
        var currentIndex = 0
        while currentIndex < requiredDeps.count {
            let endIndex = min(currentIndex + maxConcurrentTasks, requiredDeps.count)
            let batch = Array(requiredDeps[currentIndex..<endIndex])
            currentIndex = endIndex

            let batchResults: [ModrinthProjectDetailVersion] = await withTaskGroup(of: ModrinthProjectDetailVersion?.self) { group in
                for dep in batch {
                    guard let projectId = dep.projectId else { continue }
                    group.addTask {
                        do {
                            let depVersion: ModrinthProjectDetailVersion

                            if let versionId = dep.versionId {
                                // 如果有 versionId，直接获取指定版本
                                depVersion = try await fetchProjectVersionThrowing(id: versionId)
                            } else {
                                // 如果没有 versionId，使用过滤逻辑获取兼容版本
                                let depVersions = try await fetchProjectVersionsFilter(
                                    id: projectId,
                                    selectedVersions: selectedVersions,
                                    selectedLoaders: selectedLoaders,
                                    type: type
                                )
                                guard let firstDepVersion = depVersions.first else {
                                    Logger.shared.warning("未找到兼容的依赖版本 (ID: \(projectId))")
                                    return nil
                                }
                                depVersion = firstDepVersion
                            }

                            return depVersion
                        } catch {
                            let globalError = GlobalError.from(error)
                            Logger.shared.error("获取依赖项目版本失败 (ID: \(projectId)): \(globalError.chineseMessage)")
                            return nil
                        }
                    }
                }

                var results: [ModrinthProjectDetailVersion] = []
                for await result in group {
                    if let version = result {
                        results.append(version)
                    }
                }

                return results
            }

            allDependencyVersions.append(contentsOf: batchResults)
        }

        // 3. 使用统一的哈希检测逻辑，基于「所有兼容版本」判断依赖是否已安装
        var missingDependencyVersions: [ModrinthProjectDetailVersion] = []

        for version in allDependencyVersions {
            let isInstalled = await isProjectInstalledByAnyCompatibleVersion(
                projectId: version.projectId,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
                modsDir: cachePath
            )

            if !isInstalled {
                missingDependencyVersions.append(version)
            }
        }

        return ModrinthProjectDependency(projects: missingDependencyVersions)
    }

    /// 使用统一逻辑判断某个项目是否已安装：
    /// 根据给定的版本 / 加载器过滤条件，获取该项目所有兼容版本，
    /// 然后检查这些版本的主文件哈希是否出现在本地缓存的哈希集合中。
    static func isProjectInstalledByAnyCompatibleVersion(
        projectId: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
        modsDir: URL
    ) async -> Bool {
        do {
            let versions: [ModrinthProjectDetailVersion]

            if projectId.hasPrefix("cf-") {
                // CurseForge 项目，使用适配后的版本列表
                versions = try await CurseForgeService.fetchProjectVersionsFilterAsModrinth(
                    id: projectId,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type
                )
            } else {
                // Modrinth 项目
                versions = try await fetchProjectVersionsFilter(
                    id: projectId,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type
                )
            }

            for version in versions {
                guard let primaryFile = filterPrimaryFiles(from: version.files) else {
                    continue
                }
                let hash = primaryFile.hashes.sha1
                let lowercasedType = type.lowercased()

                if lowercasedType == ResourceType.mod.rawValue {
                    if ModScanner.shared.isModInstalledSync(hash: hash, in: modsDir) {
                        return true
                    }
                } else {
                    let isInstalled = await ModScanner.shared.isResourceInstalledByHash(
                        hash,
                        in: modsDir
                    )
                    if isInstalled {
                        return true
                    }
                }
            }
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查项目安装状态失败 (ID: \(projectId)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }

        return false
    }

    static func fetchProjectVersionThrowing(id: String) async throws -> ModrinthProjectDetailVersion {
        let url = URLConfig.API.Modrinth.versionId(versionId: id)

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailVersion.self, from: data)
    }

    // 过滤主文件
    static func filterPrimaryFiles(from files: [ModrinthVersionFile]?) -> ModrinthVersionFile? {
        return files?.first { $0.primary == true }
    }

    static func fetchModrinthDetail(by hash: String, completion: @escaping (ModrinthProjectDetail?) -> Void) {
        let url = URLConfig.API.Modrinth.versionFile(hash: hash)
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }

            let decoder = JSONDecoder()
            decoder.configureForModrinth()

            guard let version = try? decoder.decode(ModrinthProjectDetailVersion.self, from: data) else {
                completion(nil)
                return
            }

            Task {
                do {
                    let detail = try await Self.fetchProjectDetailsThrowing(id: version.projectId)
                    await MainActor.run {
                        completion(detail)
                    }
                } catch {
                    let globalError = GlobalError.from(error)
                    Logger.shared.error("通过哈希获取项目详情失败 (Hash: \(hash)): \(globalError.chineseMessage)")
                    GlobalErrorHandler.shared.handle(globalError)
                    await MainActor.run {
                        completion(nil)
                    }
                }
            }
        }
        task.resume()
    }
}
