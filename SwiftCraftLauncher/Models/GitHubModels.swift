import Foundation

// MARK: - GitHub Contributor Model
public struct GitHubContributor: Codable, Identifiable {
    public let id: Int
    public let login: String
    public let nodeId: String
    public let avatarUrl: String
    public let gravatarId: String?
    public let url: String
    public let htmlUrl: String
    public let followersUrl: String
    public let followingUrl: String
    public let gistsUrl: String
    public let starredUrl: String
    public let subscriptionsUrl: String
    public let organizationsUrl: String
    public let reposUrl: String
    public let eventsUrl: String
    public let receivedEventsUrl: String
    public let type: String
    public let siteAdmin: Bool
    public let contributions: Int
      
    enum CodingKeys: String, CodingKey {
        case id
        case login
        case nodeId = "node_id"
        case avatarUrl = "avatar_url"
        case gravatarId = "gravatar_id"
        case url
        case htmlUrl = "html_url"
        case followersUrl = "followers_url"
        case followingUrl = "following_url"
        case gistsUrl = "gists_url"
        case starredUrl = "starred_url"
        case subscriptionsUrl = "subscriptions_url"
        case organizationsUrl = "organizations_url"
        case reposUrl = "repos_url"
        case eventsUrl = "events_url"
        case receivedEventsUrl = "received_events_url"
        case type
        case siteAdmin = "site_admin"
        case contributions
    }
}

// MARK: - GitHub Repository Model
public struct GitHubRepository: Codable, Identifiable {
    public let id: Int
    public let nodeId: String
    public let name: String
    public let fullName: String
    public let `private`: Bool
    public let owner: GitHubUser
    public let htmlUrl: String
    public let description: String?
    public let fork: Bool
    public let url: String
    public let stargazersCount: Int
    public let watchersCount: Int
    public let language: String?
    public let forksCount: Int
    public let openIssuesCount: Int
    public let defaultBranch: String
    public let subscribersCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case nodeId = "node_id"
        case name
        case fullName = "full_name"
        case `private`
        case owner
        case htmlUrl = "html_url"
        case description
        case fork
        case url
        case stargazersCount = "stargazers_count"
        case watchersCount = "watchers_count"
        case language
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case defaultBranch = "default_branch"
        case subscribersCount = "subscribers_count"
    }
}

// MARK: - GitHub User Model
public struct GitHubUser: Codable, Identifiable {
    public let id: Int
    public let login: String
    public let nodeId: String
    public let avatarUrl: String
    public let gravatarId: String?
    public let url: String
    public let htmlUrl: String
    public let type: String
    public let siteAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case nodeId = "node_id"
        case avatarUrl = "avatar_url"
        case gravatarId = "gravatar_id"
        case url
        case htmlUrl = "html_url"
        case type
        case siteAdmin = "site_admin"
    }
}

// MARK: - GitHub API Error
public struct GitHubAPIError: Codable, Error {
    public let message: String
    public let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}
