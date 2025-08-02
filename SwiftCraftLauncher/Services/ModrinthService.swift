import Foundation

enum ModrinthService {

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
        do {
            return try await searchProjectsThrowing(
                facets: facets,
                index: index,
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
            return try JSONDecoder().decode(ModrinthResult.self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
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
            return try JSONDecoder().decode([Loader].self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
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
            return try JSONDecoder().decode([Category].self, from: data)
        } catch {
            let globalError = GlobalError.from(error)
            throw globalError
        }
    }

    /// 获取游戏版本列表（静默版本）
    /// - Returns: 游戏版本列表，失败时返回空数组
    static func fetchGameVersions() async -> [GameVersion] {
        do {
            return try await fetchGameVersionsThrowing()
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
            return try await fetchProjectDetailsThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 获取项目详情（抛出异常版本）
    /// - Parameter id: 项目 ID
    /// - Returns: 项目详情
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectDetailsThrowing(id: String) async throws -> ModrinthProjectDetail {
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
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            Logger.shared.info("Modrinth 搜索 URL：\(url)")
            return try decoder.decode(ModrinthProjectDetail.self, from: data)
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
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
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
                let loaderMatch = loaders.isEmpty || !Set(version.loaders).isDisjoint(with: selectedLoaders)
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
        
        // 2. 收集所有依赖的projectId
        var dependencyProjectIds = Set<String>()
        
        let missingIds = firstVersion.dependencies
            .filter { $0.dependencyType == "required" }
            .compactMap(\.projectId)
            .filter { !ModScanner.shared.isModInstalledSync(projectId: $0, in: cachePath) }

        missingIds.forEach { dependencyProjectIds.insert($0) }
        
        // 3. 获取所有依赖项目详情
        var dependencyProjects: [ModrinthProjectDetail] = []
        for depId in dependencyProjectIds {
            do {
                let detail = try await fetchProjectDetailsThrowing(id: depId)
                dependencyProjects.append(detail)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("获取依赖项目详情失败 (ID: \(depId)): \(globalError.chineseMessage)")
            }
        }
        // 4. 只返回第一个版本
        let _: [ModrinthProjectDetailVersion] = [firstVersion]
        return ModrinthProjectDependency(projects: dependencyProjects)
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
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            guard let version = try? decoder.decode(ModrinthProjectDetailVersion.self, from: data) else {
                completion(nil)
                return
            }
            
            Task {
                do {
                    let detail = try await ModrinthService.fetchProjectDetailsThrowing(id: version.id)
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


