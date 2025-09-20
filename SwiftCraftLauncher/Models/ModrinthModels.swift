import Foundation

// Modrinth 项目模型
public struct ModrinthProject: Codable {
    let projectId: String
    let projectType: String
    let slug: String
    let author: String
    let title: String
    let description: String
    let categories: [String]
    let displayCategories: [String]
    let versions: [String]
    let downloads: Int
    let follows: Int
    let iconUrl: String?
    let license: String
    let clientSide: String
    let serverSide: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectType = "project_type"
        case slug, author, title, description, categories
        case displayCategories = "display_categories"
        case versions, downloads, follows
        case iconUrl = "icon_url"
        case license
        case clientSide = "client_side"
        case serverSide = "server_side"
    }
}

public struct ModrinthProjectDetail: Codable, Hashable, Equatable {
    let slug: String
    let title: String
    let description: String
    let categories: [String]
    let clientSide: String
    let serverSide: String
    let body: String
    let additionalCategories: [String]?
    let issuesUrl: String?
    let sourceUrl: String?
    let wikiUrl: String?
    let discordUrl: String?
    let projectType: String
    let downloads: Int
    let iconUrl: String?
    let id: String
    let team: String
    let published: Date
    let updated: Date
    let followers: Int
    let license: License?
    let versions: [String]
    let gameVersions: [String]
    let loaders: [String]
    var type: String?
    var fileName: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case description
        case categories
        case clientSide = "client_side"
        case serverSide = "server_side"
        case body
        case additionalCategories = "additional_categories"
        case issuesUrl = "issues_url"
        case sourceUrl = "source_url"
        case wikiUrl = "wiki_url"
        case discordUrl = "discord_url"
        case projectType = "project_type"
        case downloads
        case iconUrl = "icon_url"
        case id
        case team
        case published
        case updated
        case followers
        case license
        case versions
        case gameVersions = "game_versions"
        case loaders
        case type
        case fileName
    }
}

// Modrinth 搜索结果模型
struct ModrinthResult: Codable {
    let hits: [ModrinthProject]
    let offset: Int
    let limit: Int
    let totalHits: Int

    enum CodingKeys: String, CodingKey {
        case hits, offset, limit
        case totalHits = "total_hits"
    }
}

// 游戏版本
struct GameVersion: Codable, Identifiable, Hashable {
    let version: String
    let version_type: String
    let date: String
    let major: Bool

    var id: String { version }
}

// 加载器
struct Loader: Codable, Identifiable {
    let name: String
    let icon: String
    let supported_project_types: [String]

    var id: String { name }
}

// 分类
struct Category: Codable, Identifiable, Hashable {
    let name: String
    let project_type: String
    let header: String

    var id: String { name }
}

// 许可证
struct License: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let url: String?
}

/// Modrinth version model
public struct ModrinthProjectDetailVersion: Codable, Identifiable, Equatable, Hashable {
    /// Game versions this version supports
    public let gameVersions: [String]

    /// Loaders this version supports
    public let loaders: [String]

    /// Version ID
    public let id: String

    /// Project ID
    public let projectId: String

    /// Author ID
    public let authorId: String

    /// Whether this version is featured
    public let featured: Bool

    /// Version name
    public let name: String

    /// Version number
    public let versionNumber: String

    /// Version changelog
    public let changelog: String?

    /// URL to changelog
    public let changelogUrl: String?

    /// Date published
    public let datePublished: Date

    /// Number of downloads
    public let downloads: Int

    /// Version type (release, beta, alpha)
    public let versionType: String

    /// Version status
    public let status: String

    /// Requested status
    public let requestedStatus: String?

    /// Version files
    public let files: [ModrinthVersionFile]

    /// Version dependencies
    public let dependencies: [ModrinthVersionDependency]

    enum CodingKeys: String, CodingKey {
        case gameVersions = "game_versions"
        case loaders
        case id
        case projectId = "project_id"
        case authorId = "author_id"
        case featured
        case name
        case versionNumber = "version_number"
        case changelog
        case changelogUrl = "changelog_url"
        case datePublished = "date_published"
        case downloads
        case versionType = "version_type"
        case status
        case requestedStatus = "requested_status"
        case files
        case dependencies
    }
}

/// Modrinth version file model
public struct ModrinthVersionFile: Codable, Equatable, Hashable {
    /// File hashes
    public let hashes: ModrinthVersionFileHashes

    /// File URL
    public let url: String

    /// File name
    public let filename: String

    /// Whether this is the primary file
    public let primary: Bool

    /// File size in bytes
    public let size: Int

    /// File type
    public let fileType: String?

    enum CodingKeys: String, CodingKey {
        case hashes
        case url
        case filename
        case primary
        case size
        case fileType = "file_type"
    }
}

/// Modrinth version file hashes model
public struct ModrinthVersionFileHashes: Codable, Equatable, Hashable {
    /// SHA512 hash
    public let sha512: String

    /// SHA1 hash
    public let sha1: String
}

/// Modrinth version dependency model
public struct ModrinthVersionDependency: Codable, Equatable, Hashable {
    /// Project ID
    public let projectId: String?

    /// Version ID
    public let versionId: String?

    /// Dependency type
    public let dependencyType: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case versionId = "version_id"
        case dependencyType = "dependency_type"
    }
}

public struct ModrinthProjectDependency: Codable, Hashable, Equatable {
    public let projects: [ModrinthProjectDetailVersion]
}

extension ModrinthProject {
    /// 从 ModrinthProjectDetail 构建 ModrinthProject
    public static func from(detail: ModrinthProjectDetail) -> ModrinthProject {
        ModrinthProject(
            projectId: detail.id,
            projectType: detail.projectType,
            slug: detail.slug,
            author: detail.team,
            title: detail.title,
            description: detail.description,
            categories: detail.categories,
            displayCategories: detail.additionalCategories ?? [],
            versions: detail.versions,
            downloads: detail.downloads,
            follows: detail.followers,
            iconUrl: detail.iconUrl,
            license: detail.license?.name ?? "",
            clientSide: detail.clientSide,
            serverSide: detail.serverSide
        )
    }

    /// 从 ModrinthProject 构建 ModrinthProjectDetail
    public func toDetail() -> ModrinthProjectDetail {
        ModrinthProjectDetail(
            slug: self.slug,
            title: self.title,
            description: self.description,
            categories: self.categories,
            clientSide: self.clientSide,
            serverSide: self.serverSide,
            body: "",
            additionalCategories: self.displayCategories,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            projectType: self.projectType,
            downloads: self.downloads,
            iconUrl: self.iconUrl,
            id: self.projectId,
            team: self.author,
            published: Date(),
            updated: Date(),
            followers: self.follows,
            license: License(id: "", name: self.license, url: nil),
            versions: self.versions,
            gameVersions: [],
            loaders: [],
            type: nil,
            fileName: nil
        )
    }
}
