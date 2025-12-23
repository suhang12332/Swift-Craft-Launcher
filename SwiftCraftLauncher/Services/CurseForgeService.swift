import Foundation

/// CurseForge 服务
/// 提供统一的 CurseForge API 访问接口
enum CurseForgeService {

    // MARK: - Public Methods

    /// 获取 CurseForge 文件详情
    /// - Parameters:
    ///   - projectId: 项目 ID
    ///   - fileId: 文件 ID
    /// - Returns: 文件详情，如果获取失败则返回 nil
    static func fetchFileDetail(projectId: Int, fileId: Int) async -> CurseForgeModFileDetail? {
        do {
            return try await fetchFileDetailThrowing(projectId: projectId, fileId: fileId)
        } catch {
            Logger.shared.error("获取 CurseForge 文件详情失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取 CurseForge 文件详情（抛出异常版本）
    /// - Parameters:
    ///   - projectId: 项目 ID
    ///   - fileId: 文件 ID
    /// - Returns: 文件详情
    /// - Throws: 网络错误或解析错误
    static func fetchFileDetailThrowing(projectId: Int, fileId: Int) async throws -> CurseForgeModFileDetail {
        // 使用配置的 CurseForge API URL
        let url = URLConfig.API.CurseForge.fileDetail(projectId: projectId, fileId: fileId)

        return try await tryFetchFileDetail(from: url.absoluteString)
    }

    /// 获取 CurseForge 模组详情
    /// - Parameter modId: 模组 ID
    /// - Returns: 模组详情，如果获取失败则返回 nil
    static func fetchModDetail(modId: Int) async -> CurseForgeModDetail? {
        do {
            return try await fetchModDetailThrowing(modId: modId)
        } catch {
            Logger.shared.error("获取 CurseForge 模组详情失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取 CurseForge 模组详情（抛出异常版本）
    /// - Parameter modId: 模组 ID
    /// - Returns: 模组详情
    /// - Throws: 网络错误或解析错误
    static func fetchModDetailThrowing(modId: Int) async throws -> CurseForgeModDetail {
        // 使用配置的 CurseForge API URL
        let url = URLConfig.API.CurseForge.modDetail(modId: modId)

        return try await tryFetchModDetail(from: url.absoluteString)
    }

    /// 获取 CurseForge 项目文件列表
    /// - Parameters:
    ///   - projectId: 项目 ID
    ///   - gameVersion: 游戏版本过滤（可选）
    ///   - modLoaderType: 模组加载器类型过滤（可选）
    /// - Returns: 文件列表，如果获取失败则返回 nil
    static func fetchProjectFiles(projectId: Int, gameVersion: String? = nil, modLoaderType: Int? = nil) async -> [CurseForgeModFileDetail]? {
        do {
            return try await fetchProjectFilesThrowing(projectId: projectId, gameVersion: gameVersion, modLoaderType: modLoaderType)
        } catch {
            Logger.shared.error("获取 CurseForge 项目文件列表失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取 CurseForge 项目文件列表（抛出异常版本）
    /// - Parameters:
    ///   - projectId: 项目 ID
    ///   - gameVersion: 游戏版本过滤（可选）
    ///   - modLoaderType: 模组加载器类型过滤（可选）
    /// - Returns: 文件列表
    /// - Throws: 网络错误或解析错误
    static func fetchProjectFilesThrowing(projectId: Int, gameVersion: String? = nil, modLoaderType: Int? = nil) async throws -> [CurseForgeModFileDetail] {
        // 从 modDetail 中解析文件信息，无需调用 projectFiles API
        let modDetail = try await fetchModDetailThrowing(modId: projectId)
        
        var files: [CurseForgeModFileDetail] = []
        
        // 首先尝试从 latestFiles 中获取文件列表
        if let latestFiles = modDetail.latestFiles, !latestFiles.isEmpty {
            files = latestFiles
        } else if let latestFilesIndexes = modDetail.latestFilesIndexes, !latestFilesIndexes.isEmpty {
            // 如果 latestFiles 不存在，从 latestFilesIndexes 构造文件详情
            // 按 fileId 分组，收集所有游戏版本
            var fileIndexMap: [Int: [CurseForgeFileIndex]] = [:]
            for index in latestFilesIndexes {
                fileIndexMap[index.fileId, default: []].append(index)
            }
            
            // 为每个唯一的 fileId 构造文件详情
            for (fileId, indexes) in fileIndexMap {
                guard let firstIndex = indexes.first else { continue }
                
                // 收集所有匹配的游戏版本
                let gameVersions = indexes.map { $0.gameVersion }
                
                // 使用 fileId 和 fileName 构建下载链接
                let downloadUrl = URLConfig.API.CurseForge.fallbackDownloadUrl(
                    fileId: fileId,
                    fileName: firstIndex.filename
                ).absoluteString
                
                // 构造文件详情
                let fileDetail = CurseForgeModFileDetail(
                    id: fileId,
                    displayName: firstIndex.filename,
                    fileName: firstIndex.filename,
                    downloadUrl: downloadUrl,
                    fileDate: "", // latestFilesIndexes 中没有日期信息
                    releaseType: firstIndex.releaseType,
                    gameVersions: gameVersions,
                    dependencies: nil,
                    changelog: nil,
                    fileLength: nil,
                    hash: nil,
                    modules: nil,
                    projectId: projectId,
                    projectName: modDetail.name,
                    authors: modDetail.authors
                )
                files.append(fileDetail)
            }
        }
        
        // 根据 gameVersion 和 modLoaderType 进行过滤
        var filteredFiles = files
        
        if let gameVersion = gameVersion {
            filteredFiles = filteredFiles.filter { file in
                file.gameVersions.contains(gameVersion)
            }
        }
        
        // 如果指定了 modLoaderType，需要从 latestFilesIndexes 中获取 modLoader 信息进行过滤
        if let modLoaderType = modLoaderType {
            if let latestFilesIndexes = modDetail.latestFilesIndexes {
                // 获取匹配 modLoaderType 的 fileId 集合
                let matchingFileIds = Set(latestFilesIndexes
                    .filter { $0.modLoader == modLoaderType }
                    .map { $0.fileId })
                
                // 只保留匹配的文件
                filteredFiles = filteredFiles.filter { file in
                    matchingFileIds.contains(file.id)
                }
            }
            // 注意：如果 latestFilesIndexes 不存在，无法进行 modLoaderType 过滤
            // 这种情况下返回所有文件（可能包含不匹配的加载器）
        }
        
        return filteredFiles
    }
    
    // MARK: - Search Methods
    
    /// 搜索项目（静默版本）
    /// - Parameters:
    ///   - gameId: 游戏 ID（Minecraft 为 432）
    ///   - classId: 内容类型 ID（可选）
    ///   - categoryId: 分类 ID（可选，会被 categoryIds 覆盖）
    ///   - categoryIds: 分类 ID 列表（可选，会覆盖 categoryId，最多 10 个）
    ///   - gameVersion: 游戏版本（可选，会被 gameVersions 覆盖）
    ///   - gameVersions: 游戏版本列表（可选，会覆盖 gameVersion，最多 4 个）
    ///   - searchFilter: 搜索关键词（可选）
    ///   - modLoaderType: 模组加载器类型（可选，会被 modLoaderTypes 覆盖）
    ///   - modLoaderTypes: 模组加载器类型列表（可选，会覆盖 modLoaderType，最多 5 个）
    ///   - index: 页码索引（可选）
    ///   - pageSize: 每页大小（可选）
    /// - Returns: 搜索结果，失败时返回空结果
    /// - Note: API 限制：categoryIds 最多 10 个，gameVersions 最多 4 个，modLoaderTypes 最多 5 个
    static func searchProjects(
        gameId: Int = 432,
        classId: Int? = nil,
        categoryId: Int? = nil,
        categoryIds: [Int]? = nil,
        gameVersion: String? = nil,
        gameVersions: [String]? = nil,
        searchFilter: String? = nil,
        modLoaderType: Int? = nil,
        modLoaderTypes: [Int]? = nil,
        index: Int = 0,
        pageSize: Int = 20
    ) async -> CurseForgeSearchResult {
        do {
            return try await searchProjectsThrowing(
                gameId: gameId,
                classId: classId,
                categoryId: categoryId,
                categoryIds: categoryIds,
                gameVersion: gameVersion,
                gameVersions: gameVersions,
                searchFilter: searchFilter,
                modLoaderType: modLoaderType,
                modLoaderTypes: modLoaderTypes,
                index: index,
                pageSize: pageSize
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索 CurseForge 项目失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return CurseForgeSearchResult(data: [], pagination: nil)
        }
    }
    
    /// 搜索项目（抛出异常版本）
    /// - Parameters:
    ///   - gameId: 游戏 ID（Minecraft 为 432）
    ///   - classId: 内容类型 ID（可选）
    ///   - categoryId: 分类 ID（可选，会被 categoryIds 覆盖）
    ///   - categoryIds: 分类 ID 列表（可选，会覆盖 categoryId，最多 10 个）
    ///   - gameVersion: 游戏版本（可选，会被 gameVersions 覆盖）
    ///   - gameVersions: 游戏版本列表（可选，会覆盖 gameVersion，最多 4 个）
    ///   - searchFilter: 搜索关键词（可选）
    ///   - modLoaderType: 模组加载器类型（可选，会被 modLoaderTypes 覆盖）
    ///   - modLoaderTypes: 模组加载器类型列表（可选，会覆盖 modLoaderType，最多 5 个）
    ///   - index: 页码索引（可选）
    ///   - pageSize: 每页大小（可选）
    /// - Returns: 搜索结果
    /// - Throws: GlobalError 当操作失败时
    /// - Note: 
    ///   - 如果不传递 sortField 和 sortOrder，将使用 CurseForge API 的默认排序（通常按相关性排序）
    ///   - API 限制：categoryIds 最多 10 个，gameVersions 最多 4 个，modLoaderTypes 最多 5 个
    static func searchProjectsThrowing(
        gameId: Int = 432,
        classId: Int? = nil,
        categoryId: Int? = nil,
        categoryIds: [Int]? = nil,
        gameVersion: String? = nil,
        gameVersions: [String]? = nil,
        /// 原始搜索关键字（会自动将空白折叠并用 "+" 连接，例如 "fabric api" -> "fabric+api"）
        searchFilter: String? = nil,
        modLoaderType: Int? = nil,
        modLoaderTypes: [Int]? = nil,
        index: Int = 0,
        pageSize: Int = 20
    ) async throws -> CurseForgeSearchResult {
        // 强制使用按总下载量降序
        let effectiveSortField = 6
        let effectiveSortOrder = "desc"

        guard var components = URLComponents(
            url: URLConfig.API.CurseForge.search,
            resolvingAgainstBaseURL: true
        ) else {
            throw GlobalError.validation(
                chineseMessage: "构建URLComponents失败",
                i18nKey: "error.validation.url_components_build_failed",
                level: .notification
            )
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: String(gameId)),
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "pageSize", value: String(min(pageSize, 50)))
        ]
        
        if let classId = classId {
            queryItems.append(URLQueryItem(name: "classId", value: String(classId)))
        }
        
        // categoryIds 会覆盖 categoryId
        // API 限制：最多 10 个分类 ID
        if let categoryIds = categoryIds, !categoryIds.isEmpty {
            let limitedCategoryIds = Array(categoryIds.prefix(10))
            // 按文档要求，使用 JSON 数组字符串格式：["6","7"]
            let stringIds = limitedCategoryIds.map { String($0) }
            let data = try JSONEncoder().encode(stringIds)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 categoryIds 失败",
                    i18nKey: "error.validation.encode_category_ids_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "categoryIds", value: jsonArrayString))
        } else if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: String(categoryId)))
        }
        
        // gameVersions 会覆盖 gameVersion
        // API 限制：最多 4 个游戏版本
        if let gameVersions = gameVersions, !gameVersions.isEmpty {
            let limitedGameVersions = Array(gameVersions.prefix(4))
            // 按 API 文档要求，使用 JSON 数组字符串格式：["1.0","1.1"]
            let data = try JSONEncoder().encode(limitedGameVersions)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 gameVersions 失败",
                    i18nKey: "error.validation.encode_game_versions_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "gameVersions", value: jsonArrayString))
        } else if let gameVersion = gameVersion {
            queryItems.append(URLQueryItem(name: "gameVersion", value: gameVersion))
        }
        
        if let rawSearchFilter = searchFilter?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !rawSearchFilter.isEmpty {
            // 将连续空白折叠，并用 "+" 连接，得到类似 "fabric+api" 的格式
            let components = rawSearchFilter
                .split { $0.isWhitespace }
                .map(String.init)
            let normalizedSearchFilter = components.joined(separator: "+")
            queryItems.append(URLQueryItem(name: "searchFilter", value: normalizedSearchFilter))
        }
        
        // 排序参数：默认强制添加 sortField=6, sortOrder=desc（总下载量倒序）
        queryItems.append(URLQueryItem(name: "sortField", value: String(effectiveSortField)))
        queryItems.append(URLQueryItem(name: "sortOrder", value: effectiveSortOrder))
        
        // modLoaderTypes 会覆盖 modLoaderType
        // API 限制：最多 5 个加载器类型
        if let modLoaderTypes = modLoaderTypes, !modLoaderTypes.isEmpty {
            let limitedModLoaderTypes = Array(modLoaderTypes.prefix(5))
            let stringTypes = limitedModLoaderTypes.map { String($0) }
            // 使用 JSON 数组字符串格式：["1","4"]
            let data = try JSONEncoder().encode(stringTypes)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 modLoaderTypes 失败",
                    i18nKey: "error.validation.encode_mod_loader_types_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "modLoaderTypes", value: jsonArrayString))
        } else if let modLoaderType = modLoaderType {
            queryItems.append(URLQueryItem(name: "modLoaderType", value: String(modLoaderType)))
        }
        
        components.queryItems = queryItems
        guard let url = components.url else {
            throw GlobalError.validation(
                chineseMessage: "构建搜索URL失败",
                i18nKey: "error.validation.search_url_build_failed",
                level: .notification
            )
        }
        
        // 打印 CurseForge API URL
        Logger.shared.info("🟠 [CurseForge API] \(url.absoluteString)")
        
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeSearchResult.self, from: data)
        
        return result
    }
    
    // MARK: - Category Methods
    
    /// 获取分类列表（静默版本）
    /// - Returns: 分类列表，失败时返回空数组
    static func fetchCategories() async -> [CurseForgeCategory] {
        do {
            return try await fetchCategoriesThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 CurseForge 分类列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取分类列表（抛出异常版本）
    /// - Returns: 分类列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchCategoriesThrowing() async throws -> [CurseForgeCategory] {
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.categories, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeCategoriesResponse.self, from: data)
        return result.data
    }
    
    // MARK: - Game Version Methods
    
    /// 获取游戏版本列表（静默版本）
    /// - Returns: 游戏版本列表，失败时返回空数组
    static func fetchGameVersions() async -> [CurseForgeGameVersion] {
        do {
            return try await fetchGameVersionsThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 CurseForge 游戏版本列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取游戏版本列表（抛出异常版本）
    /// - Returns: 游戏版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchGameVersionsThrowing() async throws -> [CurseForgeGameVersion] {
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.gameVersions, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeGameVersionsResponse.self, from: data)
        // 只返回已批准且为正式版的版本
        return result.data.filter { $0.approved && $0.version_type == "release" }
    }
    
    // MARK: - Project Detail Methods (as Modrinth format)
    
    /// 获取项目详情（映射为 Modrinth 格式，静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: Modrinth 格式的项目详情，失败时返回 nil
    static func fetchProjectDetailsAsModrinth(id: String) async -> ModrinthProjectDetail? {
        do {
            return try await fetchProjectDetailsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 获取项目详情（映射为 Modrinth 格式，抛出异常版本）
    /// - Parameter id: 项目 ID（可能包含 "cf-" 前缀）
    /// - Returns: Modrinth 格式的项目详情
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectDetailsAsModrinthThrowing(id: String) async throws -> ModrinthProjectDetail {
        // 移除 "cf-" 前缀（如果存在）
        let cleanId = id.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(cleanId) else {
            throw GlobalError.validation(
                chineseMessage: "无效的项目 ID",
                i18nKey: "error.validation.invalid_project_id",
                level: .notification
            )
        }
        
        let cfDetail = try await fetchModDetailThrowing(modId: modId)
        guard let modrinthDetail = CurseForgeToModrinthAdapter.convert(cfDetail) else {
            throw GlobalError.validation(
                chineseMessage: "转换项目详情失败",
                i18nKey: "error.validation.project_detail_convert_failed",
                level: .notification
            )
        }
        return modrinthDetail
    }
    
    /// 获取项目版本列表（映射为 Modrinth 格式，静默版本）
    /// - Parameter id: 项目 ID
    /// - Returns: Modrinth 格式的版本列表，失败时返回空数组
    static func fetchProjectVersionsAsModrinth(id: String) async -> [ModrinthProjectDetailVersion] {
        do {
            return try await fetchProjectVersionsAsModrinthThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目版本列表失败 (ID: \(id)): \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取项目版本列表（映射为 Modrinth 格式，抛出异常版本）
    /// - Parameter id: 项目 ID（可能包含 "cf-" 前缀）
    /// - Returns: Modrinth 格式的版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionsAsModrinthThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        // 移除 "cf-" 前缀（如果存在）
        let cleanId = id.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(cleanId) else {
            throw GlobalError.validation(
                chineseMessage: "无效的项目 ID",
                i18nKey: "error.validation.invalid_project_id",
                level: .notification
            )
        }
        
        let cfFiles = try await fetchProjectFilesThrowing(projectId: modId)
        // 确保传递的 projectId 包含 "cf-" 前缀
        let normalizedId = id.hasPrefix("cf-") ? id : "cf-\(cleanId)"
        return cfFiles.compactMap { CurseForgeToModrinthAdapter.convertVersion($0, projectId: normalizedId) }
    }
    
    /// 获取项目版本列表（过滤版本，映射为 Modrinth 格式）
    /// - Parameters:
    ///   - id: 项目 ID（可能包含 "cf-" 前缀）
    ///   - selectedVersions: 选中的版本
    ///   - selectedLoaders: 选中的加载器
    ///   - type: 项目类型
    /// - Returns: 过滤后的 Modrinth 格式版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchProjectVersionsFilterAsModrinth(
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String
    ) async throws -> [ModrinthProjectDetailVersion] {
        // 移除 "cf-" 前缀（如果存在）
        let cleanId = id.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(cleanId) else {
            throw GlobalError.validation(
                chineseMessage: "无效的项目 ID",
                i18nKey: "error.validation.invalid_project_id",
                level: .notification
            )
        }
        
        // 对于光影包、资源包、数据包，CurseForge API 不支持 modLoaderType 过滤
        let resourceTypeLowercased = type.lowercased()
        let shouldFilterByLoader = !(resourceTypeLowercased == "shader" || 
                                     resourceTypeLowercased == "resourcepack" || 
                                     resourceTypeLowercased == "datapack")
        
        // 转换加载器名称到 CurseForge ModLoaderType（仅对需要过滤加载器的资源类型）
        var modLoaderTypes: [Int] = []
        if shouldFilterByLoader {
            for loader in selectedLoaders {
                if let loaderType = CurseForgeModLoaderType.from(loader) {
                    modLoaderTypes.append(loaderType.rawValue)
                }
            }
        }
        
        // 获取文件列表
        var cfFiles: [CurseForgeModFileDetail] = []
        if !selectedVersions.isEmpty {
            // 如果有选中的版本，为每个版本获取文件
            for version in selectedVersions {
                // 对于光影包、资源包、数据包，不传递 modLoaderType 参数
                let files = try await fetchProjectFilesThrowing(
                    projectId: modId,
                    gameVersion: version,
                    modLoaderType: shouldFilterByLoader && !modLoaderTypes.isEmpty ? modLoaderTypes.first : nil
                )
                cfFiles.append(contentsOf: files)
            }
        } else {
            cfFiles = try await fetchProjectFilesThrowing(projectId: modId)
        }
        
        // 过滤文件
        let filteredFiles = cfFiles.filter { file in
            // 版本匹配
            let versionMatch = selectedVersions.isEmpty || !Set(file.gameVersions).isDisjoint(with: selectedVersions)
            
            // 对于光影包、资源包、数据包，不需要检查加载器匹配
            // 对于其他类型，如果指定了加载器，需要匹配（但CurseForge API可能不返回加载器信息，所以这里简化处理）
            let loaderMatch = !shouldFilterByLoader || modLoaderTypes.isEmpty || true
            
            return versionMatch && loaderMatch
        }
        
        // 转换为 Modrinth 格式，确保 projectId 包含 "cf-" 前缀
        let normalizedId = id.hasPrefix("cf-") ? id : "cf-\(cleanId)"
        return filteredFiles.compactMap { CurseForgeToModrinthAdapter.convertVersion($0, projectId: normalizedId) }
    }
    
    /// 过滤出主要文件
    static func filterPrimaryFiles(from files: [CurseForgeModFileDetail]?) -> CurseForgeModFileDetail? {
        // CurseForge 没有 primary 字段，返回第一个文件
        return files?.first
    }

    // MARK: - Private Methods

    /// 尝试从指定 URL 获取文件详情
    /// - Parameter urlString: API URL
    /// - Returns: 文件详情
    /// - Throws: 网络错误或解析错误
    private static func tryFetchFileDetail(from urlString: String) async throws -> CurseForgeModFileDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: url, headers: headers)

        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeFileResponse.self, from: data)
        return result.data
    }

    /// 尝试从指定 URL 获取模组详情
    /// - Parameter urlString: API URL
    /// - Returns: 模组详情
    /// - Throws: 网络错误或解析错误
    private static func tryFetchModDetail(from urlString: String) async throws -> CurseForgeModDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: url, headers: headers)

        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeModDetailResponse.self, from: data)
        return result.data
    }

}
/// CurseForge 文件响应
private struct CurseForgeFileResponse: Codable {
    let data: CurseForgeModFileDetail
}
