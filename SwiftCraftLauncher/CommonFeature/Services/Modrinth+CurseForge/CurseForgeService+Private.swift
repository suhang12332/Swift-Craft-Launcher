import Foundation

extension CurseForgeService {
    // MARK: - Private Methods

    /// 尝试从指定 URL 获取文件详情
    /// - Parameter urlString: API URL
    /// - Returns: 文件详情
    /// - Throws: 网络错误或解析错误
    static func tryFetchFileDetail(from urlString: String) async throws -> CurseForgeModFileDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeFileResponse.self, from: data)
        return result.data
    }

    /// 尝试从指定 URL 获取模组详情
    /// - Parameter urlString: API URL
    /// - Returns: 模组详情
    /// - Throws: 网络错误或解析错误
    static func tryFetchModDetail(from urlString: String) async throws -> CurseForgeModDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeModDetailResponse.self, from: data)
        return result.data
    }

    /// 尝试从指定 URL 获取模组描述
    /// - Parameter urlString: API URL
    /// - Returns: HTML 格式的描述内容
    /// - Throws: 网络错误或解析错误
    static func tryFetchModDescription(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        // 解析响应
        let result = try JSONDecoder().decode(CurseForgeModDescriptionResponse.self, from: data)
        return result.data
    }

    /// 解析 CF ID，返回纯数字 ID 与带前缀的标准 ID
    static func parseCurseForgeId(_ id: String) throws -> (modId: Int, normalized: String) {
        let cleanId = id.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(cleanId) else {
            throw GlobalError.validation(
                chineseMessage: "无效的项目 ID",
                i18nKey: "error.validation.invalid_project_id",
                level: .notification
            )
        }
        let normalizedId = id.hasPrefix("cf-") ? id : "cf-\(cleanId)"
        return (modId, normalizedId)
    }

    static func fetchFingerprintMatchesThrowing(fingerprint: UInt32) async throws -> CurseForgeFingerprintMatchesResponse {
        let url = URLConfig.API.CurseForge.fingerprints
        let headers = getHeaders()

        let requestBody = CurseForgeFingerprintMatchesRequest(fingerprints: [fingerprint])
        let body = try JSONEncoder().encode(requestBody)

        let data = try await APIClient.post(url: url, body: body, headers: headers)
        return try JSONDecoder().decode(CurseForgeFingerprintMatchesResponse.self, from: data)
    }
}

/// CurseForge 文件响应（供 extension 解码使用）
struct CurseForgeFileResponse: Codable {
    let data: CurseForgeModFileDetail
}
