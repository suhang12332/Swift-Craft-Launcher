import Foundation

extension CurseForgeService {
    // MARK: - Category Methods

    /// 获取分类列表（静默版本）
    /// - Returns: 分类列表，失败时返回空数组
    static func fetchCategories() async -> [CurseForgeCategory] {
        do {
            return try await fetchCategoriesThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 CurseForge 分类列表失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    /// 获取分类列表（抛出异常版本）
    /// - Returns: 分类列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchCategoriesThrowing() async throws -> [CurseForgeCategory] {
        let headers = getHeaders()
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
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    /// 获取游戏版本列表（抛出异常版本）
    /// - Returns: 游戏版本列表
    /// - Throws: GlobalError 当操作失败时
    static func fetchGameVersionsThrowing() async throws -> [CurseForgeGameVersion] {
        let headers = getHeaders()
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.gameVersions, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeGameVersionsResponse.self, from: data)
        // 只返回已批准且为正式版的版本
        return result.data.filter { $0.approved && $0.version_type == "release" }
    }
}
