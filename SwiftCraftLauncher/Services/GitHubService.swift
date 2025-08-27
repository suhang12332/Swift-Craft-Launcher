import Foundation

// MARK: - GitHub Service
@MainActor
public class GitHubService: ObservableObject {

    public static let shared = GitHubService()

    // MARK: - Public Methods

    /// 获取仓库贡献者列表
    public func fetchContributors(perPage: Int = 50) async throws -> [GitHubContributor] {
        let url = URLConfig.API.GitHub.contributors(perPage: perPage)
        let (data, _) = try await NetworkManager.shared.data(from: url)
        return try JSONDecoder().decode([GitHubContributor].self, from: data)
    }
}
