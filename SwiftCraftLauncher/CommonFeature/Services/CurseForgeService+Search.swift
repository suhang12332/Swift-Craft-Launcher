import Foundation

extension CurseForgeService {
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
            AppServices.errorHandler.handle(globalError)
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

        var components = URLComponents(
            url: URLConfig.API.CurseForge.search,
            resolvingAgainstBaseURL: true
        )

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: String(gameId)),
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "pageSize", value: String(min(pageSize, 50))),
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

        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw GlobalError.validation(
                chineseMessage: "构建搜索URL失败",
                i18nKey: "error.validation.search_url_build_failed",
                level: .notification
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeSearchResult.self, from: data)

        return result
    }
}
