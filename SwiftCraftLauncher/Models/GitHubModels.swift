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

// MARK: - GitHub Release Model
public struct GitHubRelease: Codable {
    public let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
