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
    let fileName: String?

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
        case fileName
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
    var gameVersions: [String]
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
public struct License: Codable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let url: String?
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

// MARK: - Modrinth Project Detail V3

public struct ModrinthProjectDetailV3: Codable, Hashable, Equatable {
    public let id: String
    public let slug: String
    public let projectTypes: [String]
    public let games: [String]
    public let gameVersions: [String]
    public let teamId: String
    public let organization: String?
    public let name: String
    public let summary: String
    public let description: String
    public let published: Date
    public let updated: Date
    public let approved: Date?
    public let queued: Date?
    public let status: String
    public let requestedStatus: String
    public let moderatorMessage: String?
    public let license: License
    public let downloads: Int
    public let followers: Int
    public let categories: [String]
    public let additionalCategories: [String]
    public let loaders: [String]
    public let versions: [String]
    public let iconUrl: String?
    public let linkUrls: ModrinthProjectLinkUrls?
    public let gallery: [ModrinthProjectGalleryItem]
    public let color: Int?
    public let threadId: String?
    public let monetizationStatus: String?
    public let sideTypesMigrationReviewStatus: String?
    public let minecraftServer: ModrinthMinecraftServerInfo?
    public let minecraftJavaServer: ModrinthMinecraftJavaServerInfo?
    public let minecraftBedrockServer: ModrinthMinecraftBedrockServerInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case projectTypes = "project_types"
        case games
        case gameVersions = "game_versions"
        case teamId = "team_id"
        case organization
        case name
        case summary
        case description
        case published
        case updated
        case approved
        case queued
        case status
        case requestedStatus = "requested_status"
        case moderatorMessage = "moderator_message"
        case license
        case downloads
        case followers
        case categories
        case additionalCategories = "additional_categories"
        case loaders
        case versions
        case iconUrl = "icon_url"
        case linkUrls = "link_urls"
        case gallery
        case color
        case threadId = "thread_id"
        case monetizationStatus = "monetization_status"
        case sideTypesMigrationReviewStatus = "side_types_migration_review_status"
        case minecraftServer = "minecraft_server"
        case minecraftJavaServer = "minecraft_java_server"
        case minecraftBedrockServer = "minecraft_bedrock_server"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        projectTypes = try container.decode([String].self, forKey: .projectTypes)
        games = try container.decode([String].self, forKey: .games)
        gameVersions = try container.decodeIfPresent([String].self, forKey: .gameVersions) ?? []
        teamId = try container.decode(String.self, forKey: .teamId)
        organization = try container.decodeIfPresent(String.self, forKey: .organization)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        description = try container.decode(String.self, forKey: .description)
        published = try container.decode(Date.self, forKey: .published)
        updated = try container.decode(Date.self, forKey: .updated)
        approved = try container.decodeIfPresent(Date.self, forKey: .approved)
        queued = try container.decodeIfPresent(Date.self, forKey: .queued)
        status = try container.decode(String.self, forKey: .status)
        requestedStatus = try container.decode(String.self, forKey: .requestedStatus)
        moderatorMessage = try container.decodeIfPresent(String.self, forKey: .moderatorMessage)
        license = try container.decode(License.self, forKey: .license)
        downloads = try container.decode(Int.self, forKey: .downloads)
        followers = try container.decode(Int.self, forKey: .followers)
        categories = try container.decode([String].self, forKey: .categories)
        additionalCategories = try container.decode([String].self, forKey: .additionalCategories)
        loaders = try container.decode([String].self, forKey: .loaders)
        versions = try container.decode([String].self, forKey: .versions)
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
        linkUrls = try container.decodeIfPresent(ModrinthProjectLinkUrls.self, forKey: .linkUrls)
        gallery = try container.decode([ModrinthProjectGalleryItem].self, forKey: .gallery)
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        threadId = try container.decodeIfPresent(String.self, forKey: .threadId)
        monetizationStatus = try container.decodeIfPresent(String.self, forKey: .monetizationStatus)
        sideTypesMigrationReviewStatus = try container.decodeIfPresent(String.self, forKey: .sideTypesMigrationReviewStatus)
        minecraftServer = try container.decodeIfPresent(ModrinthMinecraftServerInfo.self, forKey: .minecraftServer)
        minecraftJavaServer = try container.decodeIfPresent(ModrinthMinecraftJavaServerInfo.self, forKey: .minecraftJavaServer)
        minecraftBedrockServer = try container.decodeIfPresent(ModrinthMinecraftBedrockServerInfo.self, forKey: .minecraftBedrockServer)
    }
}

public struct ModrinthProjectLinkUrls: Codable, Hashable, Equatable {
    public let store: ModrinthProjectLinkUrl?
    public let wiki: ModrinthProjectLinkUrl?
    public let discord: ModrinthProjectLinkUrl?
    public let site: ModrinthProjectLinkUrl?
}

public struct ModrinthProjectLinkUrl: Codable, Hashable, Equatable {
    public let platform: String
    public let donation: Bool
    public let url: String
}

public struct ModrinthProjectGalleryItem: Codable, Hashable, Equatable {
    public let url: String
    public let rawUrl: String
    public let featured: Bool
    public let name: String
    public let description: String?
    public let created: Date
    public let ordering: Int

    enum CodingKeys: String, CodingKey {
        case url
        case rawUrl = "raw_url"
        case featured
        case name
        case description
        case created
        case ordering
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        rawUrl = try container.decode(String.self, forKey: .rawUrl)
        featured = try container.decode(Bool.self, forKey: .featured)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        created = try container.decode(Date.self, forKey: .created)
        ordering = try container.decode(Int.self, forKey: .ordering)
    }
}

public struct ModrinthMinecraftServerInfo: Codable, Hashable, Equatable {
    public let maxPlayers: Int?
    public let country: String?
    public let region: String?
    public let languages: [String]
    public let activeVersion: String?

    enum CodingKeys: String, CodingKey {
        case maxPlayers = "max_players"
        case country
        case region
        case languages
        case activeVersion = "active_version"
    }
}

public struct ModrinthMinecraftJavaServerInfo: Codable, Hashable, Equatable {
    public let address: String
    public let content: ModrinthMinecraftJavaServerContent?
    public let ping: ModrinthMinecraftJavaServerPing?
    public let verifiedPlays2w: Int?
    public let verifiedPlays4w: Int?

    enum CodingKeys: String, CodingKey {
        case address
        case content
        case ping
        case verifiedPlays2w = "verified_plays_2w"
        case verifiedPlays4w = "verified_plays_4w"
    }
}

public struct ModrinthMinecraftJavaServerContent: Codable, Hashable, Equatable {
    public let kind: String

    public let versionId: String?
    public let projectId: String?
    public let projectName: String?
    public let projectIcon: String?
    public let supportedGameVersions: [String]?
    public let recommendedGameVersion: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case versionId = "version_id"
        case projectId = "project_id"
        case projectName = "project_name"
        case projectIcon = "project_icon"
        case supportedGameVersions = "supported_game_versions"
        case recommendedGameVersion = "recommended_game_version"
    }
}

public struct ModrinthMinecraftJavaServerPing: Codable, Hashable, Equatable {
    public let when: Date
    public let address: String
    public let data: ModrinthMinecraftJavaServerPingData
}

public struct ModrinthMinecraftJavaServerPingData: Codable, Hashable, Equatable {
    public let latency: ModrinthLatency
    public let versionName: String
    public let versionProtocol: Int
    public let description: String
    public let playersOnline: Int
    public let playersMax: Int

    enum CodingKeys: String, CodingKey {
        case latency
        case versionName = "version_name"
        case versionProtocol = "version_protocol"
        case description
        case playersOnline = "players_online"
        case playersMax = "players_max"
    }
}

public struct ModrinthLatency: Codable, Hashable, Equatable {
    public let secs: Int
    public let nanos: Int
}

public struct ModrinthMinecraftBedrockServerInfo: Codable, Hashable, Equatable {
    public let address: String
}
