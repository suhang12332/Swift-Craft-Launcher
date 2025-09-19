import Foundation

// MARK: - GitHub Contributor Model
public struct GitHubContributor: Codable, Identifiable {
    public let id: Int
    public let login: String
    public let avatarUrl: String
    public let htmlUrl: String
    public let contributions: Int

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case contributions
    }
}
