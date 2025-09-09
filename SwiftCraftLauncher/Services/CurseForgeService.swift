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
        
        // 创建请求
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.download.invalid_http_response",
                level: .notification
            )
        }
        
        guard httpResponse.statusCode == 200 else {
            Logger.shared.error("镜像 API 请求失败，状态码: \(httpResponse.statusCode)")
            throw GlobalError.network(
                chineseMessage: "API 请求失败，状态码: \(httpResponse.statusCode)",
                i18nKey: "error.network.url",
                level: .notification
            )
        }
        
        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeFileResponse.self, from: data)
        return result.data
    }
}

// MARK: - Supporting Models

/// CurseForge 文件响应
private struct CurseForgeFileResponse: Codable {
    let data: CurseForgeModFileDetail
}

