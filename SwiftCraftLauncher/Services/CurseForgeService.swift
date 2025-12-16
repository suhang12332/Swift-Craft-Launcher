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
        // 使用配置的 CurseForge API URL，支持查询参数
        let url = URLConfig.API.CurseForge.projectFiles(projectId: projectId, gameVersion: gameVersion, modLoaderType: modLoaderType)

        return try await tryFetchProjectFiles(from: url.absoluteString)
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

    /// 尝试从指定 URL 获取项目文件列表
    /// - Parameter urlString: API URL
    /// - Returns: 文件列表
    /// - Throws: 网络错误或解析错误
    private static func tryFetchProjectFiles(from urlString: String) async throws -> [CurseForgeModFileDetail] {
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
        let result = try JSONDecoder().decode(CurseForgeFilesResult.self, from: data)
        return result.data
    }
}

// MARK: - Supporting Models

/// CurseForge 文件响应
private struct CurseForgeFileResponse: Codable {
    let data: CurseForgeModFileDetail
}
