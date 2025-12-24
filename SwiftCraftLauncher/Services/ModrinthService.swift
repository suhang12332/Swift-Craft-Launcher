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

    /// 直接从 Modrinth API 获取指定版本的详细信息
    /// - Parameter version: 版本号（如 "1.21.1"）
    /// - Returns: 版本信息
    /// - Throws: GlobalError 当操作失败时
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

    /// 直接从 Modrinth API 获取指定版本的详细信息（抛出异常版本）
    /// - Parameter version: 版本号（如 "1.21.1"）
    /// - Returns: 版本信息
    /// - Throws: GlobalError 当操作失败时
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

    /// 搜索项目（静默版本）
    /// - Parameters:
    ///   - facets: 搜索条件
    ///   - index: 索引类型
    ///   - offset: 偏移量
    ///   - limit: 限制数量
    ///   - query: 查询字符串
    /// - Returns: 搜索结果，失败时返回空结果
    static func searchProjects(
        facets: [[String]]? = nil,
        offset: Int = 0,
        limit: Int,
        query: String?
    ) async -> ModrinthResult {
        return await Task {
            try await searchProjectsThrowing(
                facets: facets,
                index: "relevance",
                offset: offset,
                limit: limit,
                query: query
            )
        }.catching { error in
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索 Modrinth 项目失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return ModrinthResult(hits: [], offset: offset, limit: limit, totalHits: 0)
        }
    }

    /// 搜索项目（抛出异常版本）
    /// - Parameters:
    ///   - facets: 搜索条件
    ///   - index: 索引类型
    ///   - offset: 偏移量
    ///   - limit: 限制数量
    ///   - query: 查询字符串
    /// - Returns: 搜索结果
    /// - Throws: GlobalError 当操作失败时
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
        
        // 打印 Modrinth API URL
        Logger.shared.info("🔵 [Modrinth API] \(url.absoluteString)")
        
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        let result = try decoder.decode(ModrinthResult.self, from: data)
        
        return result
    }

    /// 获取加载器列表（静默版本）
    /// - Returns: 加载器列表，失败时返回空数组
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

    /// 获取加载器列表（抛出异常版本）
    /// - Returns: 加载器列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchLoadersThrowing() async throws -> [Loader] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.loaderTag)
        let result = try JSONDecoder().decode([Loader].self, from: data)
        return result
    }

    /// 获取分类列表（静默版本）
    /// - Returns: 分类列表，失败时返回空数组
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

    /// 获取分类列表（抛出异常版本）
    /// - Returns: 分类列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchCategoriesThrowing() async throws -> [Category] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.categoryTag)
        let result = try JSONDecoder().decode([Category].self, from: data)
        return result
    }

    /// 获取游戏版本列表（静默版本）
    /// - Returns: 游戏版本列表，失败时返回空数组
    static func fetchGameVersions() async -> [GameVersion] {
        do {
            return try await fetchGameVersionsThrowing().filter { $0.version_type == "release" }
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 游戏版本列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取游戏版本列表（抛出异常版本）
    /// - Returns: 游戏版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchGameVersionsThrowing() async throws -> [GameVersion] {
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.gameVersionTag)
        let result = try JSONDecoder().decode([GameVersion].self, from: data)
        return result.filter { $0.version_type == "release" }
    }

    /// 获取项目详情（静默版本）
    /// - Parameter id: 项目 ID（如果以 "cf-" 开头，则使用 CurseForge 服务）
    /// - Returns: 项目详情，失败时返回 nil
    static func fetchProjectDetails(id: String) async -> ModrinthProjectDetail? {
        // 检查是否是 CurseForge 项目（ID 以 "cf-" 开头）
        if id.hasPrefix("cf-") {
            return await CurseForgeService.fetchProjectDetailsAsModrinth(id: id)
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

    /// 获取项目详情（抛出异常版本）
    /// - Parameter id: 项目 ID（如果以 "cf-" 开头，则使用 CurseForge 服务）
    /// - Returns: 项目详情
    /// - Throws: GlobalError 当操作失败时
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
        detail.gameVersions = CommonUtil.sortMinecraftVersions(releaseGameVersions)

        return detail
    }

    /// 获取项目版本列表（静默版本）
    /// - Parameter id: 项目 ID（如果以 "cf-" 开头，则使用 CurseForge 服务）
    /// - Returns: 版本列表，失败时返回空数组
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

    /// 获取项目版本列表（抛出异常版本）
    /// - Parameter id: 项目 ID（如果以 "cf-" 开头，则使用 CurseForge 服务）
    /// - Returns: 版本列表
    /// - Throws: GlobalError 当操作失败时
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

    /// 获取项目版本列表（过滤版本）
    /// - Parameters:
    ///   - id: 项目 ID（如果以 "cf-" 开头，则使用 CurseForge 服务）
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    ///   - type: 项目类型
    /// - Returns: 过滤后的版本列表
    /// - Throws: GlobalError 当操作失败时
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
            if type == "datapack" {
                loaders = ["datapack"]
            } else if type == "resourcepack" {
                loaders = ["minecraft"]
            }
            return versions.filter { version in
                // 必须同时满足版本和 loader 匹配
                let versionMatch = selectedVersions.isEmpty || !Set(version.gameVersions).isDisjoint(with: selectedVersions)

                // 对于shader和resourcepack，不检查loader匹配
                let loaderMatch: Bool
                if type == "shader" || type == "resourcepack" {
                    loaderMatch = true
                } else {
                    loaderMatch = loaders.isEmpty || !Set(version.loaders).isDisjoint(with: loaders)
                }

                return versionMatch && loaderMatch
            }
        }

    /// 获取项目依赖（静默版本）
    /// - Parameters:
    ///   - type: 项目类型
    ///   - cachePath: 缓存路径
    ///   - id: 项目 ID
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    /// - Returns: 项目依赖，失败时返回空依赖
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

    /// 获取项目依赖（抛出异常版本）
    /// - Parameters:
    ///   - type: 项目类型
    ///   - cachePath: 缓存路径
    ///   - id: 项目 ID
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    /// - Returns: 项目依赖
    /// - Throws: GlobalError 当操作失败时
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

        // 2. 并发获取所有依赖项目的兼容版本
        let allDependencyVersions: [ModrinthProjectDetailVersion] = await withTaskGroup(of: ModrinthProjectDetailVersion?.self) { group in
            for dep in firstVersion.dependencies where dep.dependencyType == "required" {
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

        // 3. 使用hash检查是否已安装，过滤出缺失的依赖
        let missingDependencyVersions = allDependencyVersions.filter { version in
            // 获取主文件的hash
            guard let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) else {
                return true // 如果没有主文件，认为缺失
            }
            // 使用hash检查是否已安装
            return !ModScanner.shared.isModInstalledSync(hash: primaryFile.hashes.sha1, in: cachePath)
        }

        return ModrinthProjectDependency(projects: missingDependencyVersions)
    }

    /// 获取单个项目版本（抛出异常版本）
    /// - Parameter id: 版本 ID
    /// - Returns: 版本信息
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionThrowing(id: String) async throws -> ModrinthProjectDetailVersion {
        let url = URLConfig.API.Modrinth.versionId(versionId: id)

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailVersion.self, from: data)
    }

    // 过滤出 primary == true 的文件
    static func filterPrimaryFiles(from files: [ModrinthVersionFile]?) -> ModrinthVersionFile? {
        return files?.first { $0.primary == true }
    }

    /// 通过文件 hash 查询 Modrinth API，返回 ModrinthProjectDetail（静默版本）
    /// - Parameter hash: 文件哈希值
    /// - Parameter completion: 完成回调
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

// Extension to support catching errors in async function returning a value.
private extension Task where Success == ModrinthResult, Failure == Error {
    func catching(_ handler: @escaping (Error) -> ModrinthResult) async -> ModrinthResult {
        do {
            return try await value
        } catch {
            return handler(error)
        }
    }
}
