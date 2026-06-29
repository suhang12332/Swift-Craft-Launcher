import Foundation

/// CurseForge 服务
/// 提供统一的 CurseForge API 访问接口
enum CurseForgeService {

    // MARK: - Private Helpers

    /// 获取 CurseForge API 请求头（包含 API key，如果可用）
    static func getHeaders() -> [String: String] {
        var headers: [String: String] = APIClient.DefaultHeaders.acceptJSON
        if let apiKey = AppConstants.curseForgeAPIKey {
            headers[APIClient.Header.xAPIKey] = apiKey
        }
        return headers
    }

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

    /// 获取 CurseForge 模组描述（抛出异常版本）
    /// - Parameter modId: 模组 ID
    /// - Returns: HTML 格式的描述内容
    /// - Throws: 网络错误或解析错误
    static func fetchModDescriptionThrowing(modId: Int) async throws -> String {
        // 使用配置的 CurseForge API URL
        let url = URLConfig.API.CurseForge.modDescription(modId: modId)

        return try await tryFetchModDescription(from: url.absoluteString)
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
    ///   - modDetail: 预先获取的模组详情（可选，用于复用减少请求）
    /// - Returns: 文件列表
    /// - Throws: 网络错误或解析错误
    static func fetchProjectFilesThrowing(
        projectId: Int,
        gameVersion: String? = nil,
        modLoaderType: Int? = nil,
    ) async throws -> [CurseForgeModFileDetail] {
        let url = URLConfig.API.CurseForge.projectFiles(
            projectId: projectId,
            gameVersion: gameVersion,
            modLoaderType: modLoaderType
        )

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeFilesResult.self, from: data)
        return result.data
    }
}
