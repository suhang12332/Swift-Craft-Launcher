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
    private static let cacheExpiration: TimeInterval = 600 // 10分钟
    
    private static var searchCache = NSCache<NSString, ModrinthResultWrapper>()
    private static var projectDetailCache = NSCache<NSString, ModrinthProjectDetailWrapper>()
    private static var gameVersionsCache = NSCache<NSString, GameVersionsWrapper>()
    private static var categoriesCache = NSCache<NSString, CategoriesWrapper>()
    private static var loadersCache = NSCache<NSString, LoadersWrapper>()
    
    private static func cacheKey(facets: [[String]]?, index: String, offset: Int, limit: Int, query: String?) -> String {
        let facetsString: String
        if let facets = facets, let data = try? JSONEncoder().encode(facets), let string = String(data: data, encoding: .utf8) {
            facetsString = string
        } else {
            facetsString = "nil"
        }
        return "facets:\(facetsString)|index:\(index)|offset:\(offset)|limit:\(limit)|query:\(query ?? "nil")"
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
        index: String,
        offset: Int = 0,
        limit: Int,
        query: String?
    ) async -> ModrinthResult {
        return await Task {
            try await searchProjectsThrowing(
                facets: facets,
                index: index,
                offset: offset,
                limit: limit,
                query: query,
                forceRefresh: false
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
    ///   - forceRefresh: 是否强制刷新缓存，默认 false
    /// - Returns: 搜索结果
    /// - Throws: GlobalError 当操作失败时
    static func searchProjectsThrowing(
        facets: [[String]]? = nil,
        index: String,
        offset: Int = 0,
        limit: Int,
        query: String?,
        forceRefresh: Bool = false
    ) async throws -> ModrinthResult {
        let key = cacheKey(facets: facets, index: index, offset: offset, limit: limit, query: query) as NSString
        
        if !forceRefresh, let cached = searchCache.object(forKey: key), Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            Logger.shared.info("使用缓存的 Modrinth 搜索结果，key：\(key)")
            return cached.result
        } else {
            searchCache.removeObject(forKey: key)
        }
        
        var components = URLComponents(
            url: URLConfig.API.Modrinth.search,
            resolvingAgainstBaseURL: true
        )!
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
        Logger.shared.info("Modrinth 搜索 URL：\(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "搜索项目失败: HTTP \(response)",
                    i18nKey: "error.download.modrinth_search_failed",
                    level: .notification
                )
            }
            let result = try JSONDecoder().decode(ModrinthResult.self, from: data)
            searchCache.setObject(ModrinthResultWrapper(result: result), forKey: key)
            return result
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取加载器列表（静默版本）
    /// - Returns: 加载器列表，失败时返回空数组
    static func fetchLoaders() async -> [Loader] {
        do {
            return try await fetchLoadersThrowing(forceRefresh: false)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 加载器列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取加载器列表（抛出异常版本）
    /// - Parameters:
    ///   - forceRefresh: 是否强制刷新缓存，默认 false
    /// - Returns: 加载器列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchLoadersThrowing(forceRefresh: Bool = false) async throws -> [Loader] {
        let key = URLConfig.API.Modrinth.Tag.loader.absoluteString as NSString
        if !forceRefresh, let cached = loadersCache.object(forKey: key), Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            Logger.shared.info("使用缓存的 Modrinth 加载器列表")
            return cached.loaders
        } else {
            loadersCache.removeObject(forKey: key)
        }
        do {
            let (data, response) = try await URLSession.shared.data(
                from: URLConfig.API.Modrinth.Tag.loader
            )
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取加载器列表失败: HTTP \(response)",
                    i18nKey: "error.download.modrinth_loaders_failed",
                    level: .notification
                )
            }
            Logger.shared.info("Modrinth 搜索 URL：\(URLConfig.API.Modrinth.Tag.loader)")
            let result = try JSONDecoder().decode([Loader].self, from: data)
            loadersCache.setObject(LoadersWrapper(loaders: result), forKey: key)
            return result
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取分类列表（静默版本）
    /// - Returns: 分类列表，失败时返回空数组
    static func fetchCategories() async -> [Category] {
        do {
            return try await fetchCategoriesThrowing(forceRefresh: false)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 分类列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取分类列表（抛出异常版本）
    /// - Parameters:
    ///   - forceRefresh: 是否强制刷新缓存，默认 false
    /// - Returns: 分类列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchCategoriesThrowing(forceRefresh: Bool = false) async throws -> [Category] {
        let key = URLConfig.API.Modrinth.Tag.category.absoluteString as NSString
        if !forceRefresh, let cached = categoriesCache.object(forKey: key), Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            Logger.shared.info("使用缓存的 Modrinth 分类列表")
            return cached.categories
        } else {
            categoriesCache.removeObject(forKey: key)
        }
        do {
            let (data, response) = try await URLSession.shared.data(
                from: URLConfig.API.Modrinth.Tag.category
            )
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取分类列表失败: HTTP \(response)",
                    i18nKey: "error.download.modrinth_categories_failed",
                    level: .notification
                )
            }
            Logger.shared.info("Modrinth 搜索 URL：\(URLConfig.API.Modrinth.Tag.category)")
            let result = try JSONDecoder().decode([Category].self, from: data)
            categoriesCache.setObject(CategoriesWrapper(categories: result), forKey: key)
            return result
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取游戏版本列表（静默版本）
    /// - Returns: 游戏版本列表，失败时返回空数组
    static func fetchGameVersions() async -> [GameVersion] {
        do {
            return try await fetchGameVersionsThrowing(forceRefresh: false)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Modrinth 游戏版本列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 获取游戏版本列表（抛出异常版本）
    /// - Parameters:
    ///   - forceRefresh: 是否强制刷新缓存，默认 false
    /// - Returns: 游戏版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchGameVersionsThrowing(forceRefresh: Bool = false) async throws -> [GameVersion] {
        let key = URLConfig.API.Modrinth.Tag.gameVersion.absoluteString as NSString
        if !forceRefresh, let cached = gameVersionsCache.object(forKey: key), Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            Logger.shared.info("使用缓存的 Modrinth 游戏版本列表")
            return cached.versions
        } else {
            gameVersionsCache.removeObject(forKey: key)
        }
        do {
            let (data, response) = try await URLSession.shared.data(
                from: URLConfig.API.Modrinth.Tag.gameVersion
            )
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取游戏版本列表失败: HTTP \(response)",
                    i18nKey: "error.download.modrinth_game_versions_failed",
                    level: .notification
                )
            }
            Logger.shared.info("Modrinth 搜索 URL：\(URLConfig.API.Modrinth.Tag.gameVersion)")
            let result = try JSONDecoder().decode([GameVersion].self, from: data)
            gameVersionsCache.setObject(GameVersionsWrapper(versions: result), forKey: key)
            return result.filter { $0.version_type == "release" }
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取项目详情（静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: 项目详情，失败时返回 nil
    static func fetchProjectDetails(id: String) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsThrowing(id: id, forceRefresh: false)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 获取项目详情（抛出异常版本）
    /// - Parameters:
    ///   - id: 项目 ID
    ///   - forceRefresh: 是否强制刷新缓存，默认 false
    /// - Returns: 项目详情
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectDetailsThrowing(id: String, forceRefresh: Bool = false) async throws -> ModrinthProjectDetail {
        let key = id as NSString
        if !forceRefresh, let cached = projectDetailCache.object(forKey: key), Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            Logger.shared.info("使用缓存的 Modrinth 项目详情，key：\(key)")
            return cached.detail
        } else {
            projectDetailCache.removeObject(forKey: key)
        }
        let url = URLConfig.API.Modrinth.project(id: id)
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取项目详情失败 (ID: \(id)): HTTP \(response)",
                    i18nKey: "error.download.modrinth_project_details_failed",
                    level: .notification
                )
            }
            
            let decoder = JSONDecoder()
            decoder.configureForModrinth()
            Logger.shared.info("Modrinth 搜索 URL：\(url)")
            let detail = try decoder.decode(ModrinthProjectDetail.self, from: data)
            projectDetailCache.setObject(ModrinthProjectDetailWrapper(detail: detail), forKey: key)
            return detail
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取项目版本列表（静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: 版本列表，失败时返回空数组
    static func fetchProjectVersions(id: String) async -> [ModrinthProjectDetailVersion] {
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
    /// - Parameter id: 项目 ID
    /// - Returns: 版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionsThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        let url = URLConfig.API.Modrinth.version(id: id)
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取项目版本列表失败 (ID: \(id)): HTTP \(response)",
                    i18nKey: "error.download.modrinth_project_versions_failed",
                    level: .notification
                )
            }
            
            let decoder = JSONDecoder()
            decoder.configureForModrinth()
            Logger.shared.info("Modrinth 搜索 URL：\(url)")
            return try decoder.decode([ModrinthProjectDetailVersion].self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }
    
    /// 获取项目版本列表（过滤版本）
    /// - Parameters:
    ///   - id: 项目 ID
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
        
        // 2. 收集所有依赖的projectId和versionId
        var dependencyProjectIds = Set<String>()
        var dependencyVersionIds: [String: String] = [:] // projectId -> versionId
        
        let missingDependencies = firstVersion.dependencies
            .filter { $0.dependencyType == "required" }
            .filter { !ModScanner.shared.isModInstalledSync(projectId: $0.projectId ?? "", in: cachePath) }

        for dep in missingDependencies {
            if let projectId = dep.projectId {
                dependencyProjectIds.insert(projectId)
                if let versionId = dep.versionId {
                    dependencyVersionIds[projectId] = versionId
                }
            }
        }
        
        // 3. 并发获取所有依赖项目的兼容版本
        let dependencyVersions: [ModrinthProjectDetailVersion] = await withTaskGroup(of: ModrinthProjectDetailVersion?.self) { group in
            for depId in dependencyProjectIds {
                group.addTask {
                    do {
                        let depVersion: ModrinthProjectDetailVersion
                        
                        if let versionId = dependencyVersionIds[depId] {
                            // 如果有 versionId，直接获取指定版本
                            depVersion = try await fetchProjectVersionThrowing(id: versionId)
                        } else {
                            // 如果没有 versionId，使用过滤逻辑获取兼容版本
                            let depVersions = try await fetchProjectVersionsFilter(
                                id: depId,
                                selectedVersions: selectedVersions,
                                selectedLoaders: selectedLoaders,
                                type: type
                            )
                            guard let firstDepVersion = depVersions.first else {
                                Logger.shared.warning("未找到兼容的依赖版本 (ID: \(depId))")
                                return nil
                            }
                            depVersion = firstDepVersion
                        }
                        
                        return depVersion
                    } catch {
                        let globalError = GlobalError.from(error)
                        Logger.shared.error("获取依赖项目版本失败 (ID: \(depId)): \(globalError.chineseMessage)")
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
        
        return ModrinthProjectDependency(projects: dependencyVersions)
    }
    
    /// 获取单个项目版本（抛出异常版本）
    /// - Parameter id: 版本 ID
    /// - Returns: 版本信息
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionThrowing(id: String) async throws -> ModrinthProjectDetailVersion {
        let url = URLConfig.API.Modrinth.versionId(versionId: id)
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "获取项目版本失败 (ID: \(id)): HTTP \(response)",
                    i18nKey: "error.download.modrinth_project_version_failed",
                    level: .notification
                )
            }
            
            let decoder = JSONDecoder()
            decoder.configureForModrinth()
            Logger.shared.info("Modrinth 版本 URL：\(url)")
            return try decoder.decode(ModrinthProjectDetailVersion.self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }
    
    // 过滤出 primary == true 的文件
    static func filterPrimaryFiles(from files: [ModrinthVersionFile]?) -> ModrinthVersionFile? {
        return files?.filter { $0.primary == true }.first
    }
    
    /// 通过文件 hash 查询 Modrinth API，返回 ModrinthProjectDetail（静默版本）
    /// - Parameter hash: 文件哈希值
    /// - Parameter completion: 完成回调
    static func fetchModrinthDetail(by hash: String, completion: @escaping (ModrinthProjectDetail?) -> Void) {
        let url = URLConfig.API.Modrinth.versionFile(hash: hash)
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
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
                    let detail = try await ModrinthService.fetchProjectDetailsThrowing(id: version.projectId)
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

private class ModrinthResultWrapper: NSObject {
    let result: ModrinthResult
    let timestamp: Date
    init(result: ModrinthResult) {
        self.result = result
        self.timestamp = Date()
    }
}

private class ModrinthProjectDetailWrapper: NSObject {
    let detail: ModrinthProjectDetail
    let timestamp: Date
    init(detail: ModrinthProjectDetail) {
        self.detail = detail
        self.timestamp = Date()
    }
}

private class GameVersionsWrapper: NSObject {
    let versions: [GameVersion]
    let timestamp: Date
    init(versions: [GameVersion]) {
        self.versions = versions
        self.timestamp = Date()
    }
}

private class CategoriesWrapper: NSObject {
    let categories: [Category]
    let timestamp: Date
    init(categories: [Category]) {
        self.categories = categories
        self.timestamp = Date()
    }
}

private class LoadersWrapper: NSObject {
    let loaders: [Loader]
    let timestamp: Date
    init(loaders: [Loader]) {
        self.loaders = loaders
        self.timestamp = Date()
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

