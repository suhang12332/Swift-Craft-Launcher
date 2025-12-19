import Foundation

// MARK: - GitHub Service
@MainActor
public class GitHubService: ObservableObject {

    public static let shared = GitHubService()

    // MARK: - Public Methods

    /// 获取仓库贡献者列表
    public func fetchContributors(perPage: Int = 50) async throws -> [GitHubContributor] {
        let url = URLConfig.API.GitHub.contributors(perPage: perPage)
        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)
        return try JSONDecoder().decode([GitHubContributor].self, from: data)
    }

    // MARK: - Static Contributors

    /// 获取静态贡献者原始数据（JSON）
    private func fetchStaticContributorsData() async throws -> Data {
        let url = URLConfig.API.GitHub.staticContributors()
        // 使用统一的 API 客户端
        return try await APIClient.get(url: url)
    }

    /// 获取静态贡献者解码后的数据
    public func fetchStaticContributors<T: Decodable>() async throws -> T {
        let data = try await fetchStaticContributorsData()
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Acknowledgements

    /// 获取开源致谢原始数据（JSON）
    private func fetchAcknowledgementsData() async throws -> Data {
        let url = URLConfig.API.GitHub.acknowledgements()
        // 使用统一的 API 客户端
        let headers = ["Accept": "application/json"]
        return try await APIClient.get(url: url, headers: headers)
    }

    /// 获取开源致谢解码后的数据
    public func fetchAcknowledgements<T: Decodable>() async throws -> T {
        let data = try await fetchAcknowledgementsData()
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - License

    /// 获取仓库 LICENSE 文本内容
    public func fetchLicenseText() async throws -> String {
        let url = URLConfig.API.GitHub.license()

        // 使用统一的 API 客户端
        let data = try await APIClient.get(url: url)

        // 解析 GitHub API 响应并直接进行 base64 解码
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["content"] as? String) ?? ""

        // 清理 base64 字符串中的换行符和空格
        // 使用 NSMutableString 避免链式调用创建多个临时字符串
        let cleanedContent = {
            let mutableContent = NSMutableString(string: content)
            mutableContent.replaceOccurrences(
                of: "\n",
                with: "",
                options: [],
                range: NSRange(location: 0, length: mutableContent.length)
            )
            mutableContent.replaceOccurrences(
                of: " ",
                with: "",
                options: [],
                range: NSRange(location: 0, length: mutableContent.length)
            )
            return mutableContent as String
        }()

        guard let decodedData = Data(base64Encoded: cleanedContent),
              let text = String(data: decodedData, encoding: .utf8) else {
            throw GitHubServiceError.invalidLicenseResponse
        }

        return text
    }

    // MARK: - Announcement

    /// 获取公告数据
    /// - Parameters:
    ///   - version: 应用版本号
    ///   - language: 语言代码
    /// - Returns: 公告数据，如果不存在（404）则返回 nil
    public func fetchAnnouncement(
        version: String,
        language: String
    ) async throws -> AnnouncementData? {
        let url = URLConfig.API.GitHub.announcement(
            version: version,
            language: language
        )

        // 使用统一的 API 客户端
        let headers = ["Accept": "application/json"]
        let data = try await APIClient.get(url: url, headers: headers)

        let announcementResponse = try JSONDecoder().decode(
            AnnouncementResponse.self,
            from: data
        )

        guard announcementResponse.success else {
            throw GitHubServiceError.announcementNotSuccessful
        }

        return announcementResponse.data
    }
}

// MARK: - GitHubService Error

public enum GitHubServiceError: Error {
    case httpError(statusCode: Int)
    case invalidResponse
    case invalidLicenseResponse
    case announcementNotSuccessful
}
