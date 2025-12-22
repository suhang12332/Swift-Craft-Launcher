import Foundation

struct CurseForgeSearchResult: Codable {
    let data: [CurseForgeMod]
    let pagination: CurseForgePagination?
}

struct CurseForgePagination: Codable {
    let index: Int
    let pageSize: Int
    let resultCount: Int
    let totalCount: Int
}

struct CurseForgeMod: Codable {
    let id: Int
    let name: String
    let summary: String
    let slug: String?
    let authors: [CurseForgeAuthor]?
    let logo: CurseForgeLogo?
    let downloadCount: Int?
    let gamePopularityRank: Int?
    let links: CurseForgeLinks?
    let dateCreated: String?
    let dateModified: String?
    let dateReleased: String?
    let gameId: Int?
    let classId: Int?
    let categories: [CurseForgeCategory]?
    let latestFiles: [CurseForgeModFileDetail]?
    let latestFilesIndexes: [CurseForgeFileIndex]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, summary, slug, authors, logo
        case downloadCount
        case gamePopularityRank
        case links
        case dateCreated
        case dateModified
        case dateReleased
        case gameId
        case classId
        case categories
        case latestFiles
        case latestFilesIndexes
    }
}

struct CurseForgeLogo: Codable {
    let id: Int?
    let modId: Int?
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let url: String?
}

struct CurseForgeLinks: Codable {
    let websiteUrl: String?
    let wikiUrl: String?
    let issuesUrl: String?
    let sourceUrl: String?
}

struct CurseForgeModDetail: Codable {
    let id: Int
    let name: String
    let summary: String
    let classId: Int
    let categories: [CurseForgeCategory]
    let slug: String?
    let authors: [CurseForgeAuthor]?
    let logo: CurseForgeLogo?
    let downloadCount: Int?
    let gamePopularityRank: Int?
    let links: CurseForgeLinks?
    let dateCreated: String?
    let dateModified: String?
    let dateReleased: String?
    let gameId: Int?
    let latestFiles: [CurseForgeModFileDetail]?
    let latestFilesIndexes: [CurseForgeFileIndex]?
    let body: String?

    /// 获取对应的内容类型枚举
    var contentType: CurseForgeClassId? {
        return CurseForgeClassId(rawValue: classId)
    }

    /// 获取目录名称
    var directoryName: String {
        return contentType?.directoryName ?? AppConstants.DirectoryNames.mods
    }
    
    /// 转换为 Modrinth 项目类型字符串
    var projectType: String {
        switch contentType {
        case .mods:
            return "mod"
        case .resourcePacks:
            return "resourcepack"
        case .shaders:
            return "shader"
        case .datapacks:
            return "datapack"
        default:
            return "mod"
        }
    }
}

struct CurseForgeFileIndex: Codable {
    let gameVersion: String
    let fileId: Int
    let filename: String
    let releaseType: Int
    let gameVersionTypeId: Int?
    let modLoader: Int?
}

/// CurseForge 内容类型枚举
enum CurseForgeClassId: Int, CaseIterable {
    case mods = 6           // 模组
    case resourcePacks = 12 // 资源包
    case shaders = 6552     // 光影
    case datapacks = 6945   // 数据包

    var directoryName: String {
        switch self {
        case .mods:
            return AppConstants.DirectoryNames.mods
        case .resourcePacks:
            return AppConstants.DirectoryNames.resourcepacks
        case .shaders:
            return AppConstants.DirectoryNames.shaderpacks
        case .datapacks:
            return AppConstants.DirectoryNames.datapacks
        }
    }
}

/// CurseForge ModLoaderType 枚举
enum CurseForgeModLoaderType: Int, CaseIterable {
    case forge = 1
    case fabric = 4
    case quilt = 5
    case neoforge = 6

    /// 根据字符串获取对应的枚举值
    /// - Parameter loaderName: 加载器名称字符串
    /// - Returns: 对应的枚举值，如果没有匹配则返回 nil
    static func from(_ loaderName: String) -> Self? {
        switch loaderName.lowercased() {
        case "forge":
            return .forge
        case "fabric":
            return .fabric
        case "quilt":
            return .quilt
        case "neoforge":
            return .neoforge
        default:
            return nil
        }
    }
}

struct CurseForgeCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String
    let url: String?
    let avatarUrl: String?
    let parentCategoryId: Int?
    let rootCategoryId: Int?
    let gameId: Int?
    let gameName: String?
    let classId: Int?
    let dateModified: String?
}

/// CurseForge 分类列表响应
struct CurseForgeCategoriesResponse: Codable {
    let data: [CurseForgeCategory]
}

/// CurseForge 游戏版本
struct CurseForgeGameVersion: Codable, Identifiable, Hashable {
    let id: Int
    let gameVersionId: Int?
    let versionString: String
    let jarDownloadUrl: String?
    let jsonDownloadUrl: String?
    let approved: Bool
    let dateModified: String?
    let gameVersionTypeId: Int?
    let gameVersionStatus: Int?
    let gameVersionTypeStatus: Int?
    
    var identifier: String { versionString }
    
    var version_type: String {
        // CurseForge 没有明确的版本类型，根据版本号推断
        if versionString.contains("snapshot") || versionString.contains("pre") || versionString.contains("rc") {
            return "snapshot"
        }
        return "release"
    }
}

/// CurseForge 游戏版本列表响应
struct CurseForgeGameVersionsResponse: Codable {
    let data: [CurseForgeGameVersion]
}

struct CurseForgeModDetailResponse: Codable {
    let data: CurseForgeModDetail
}

struct CurseForgeFilesResult: Codable {
    let data: [CurseForgeModFileDetail]
}

struct CurseForgeModFileDetail: Codable {
    let id: Int
    let displayName: String
    let fileName: String
    let downloadUrl: String?
    let fileDate: String
    let releaseType: Int
    let gameVersions: [String]
    let dependencies: [CurseForgeDependency]?
    let changelog: String?
    let fileLength: Int?
    let hash: CurseForgeHash?
    let modules: [CurseForgeModule]?
    let projectId: Int?
    let projectName: String?
    let authors: [CurseForgeAuthor]?
}

struct CurseForgeDependency: Codable {
    let modId: Int
    let relationType: Int
}

struct CurseForgeHash: Codable {
    let value: String
    let algo: Int
}

struct CurseForgeModule: Codable {
    let name: String
    let fingerprint: Int
}

struct CurseForgeAuthor: Codable {
    let name: String
    let url: String?
}

// MARK: - CurseForge Manifest Models

/// CurseForge 整合包的 manifest.json 格式
struct CurseForgeManifest: Codable {
    let minecraft: CurseForgeMinecraft
    let manifestType: String
    let manifestVersion: Int
    let name: String
    let version: String?  // 修改为可选类型，因为某些整合包可能缺少此字段
    let author: String?
    let files: [CurseForgeManifestFile]
    let overrides: String?

    enum CodingKeys: String, CodingKey {
        case minecraft
        case manifestType
        case manifestVersion
        case name
        case version
        case author
        case files
        case overrides
    }
}

/// CurseForge manifest 中的 Minecraft 配置
struct CurseForgeMinecraft: Codable {
    let version: String
    let modLoaders: [CurseForgeModLoader]
}

/// CurseForge manifest 中的模组加载器配置
struct CurseForgeModLoader: Codable {
    let id: String
    let primary: Bool
}

/// CurseForge manifest 中的文件信息
struct CurseForgeManifestFile: Codable {
    let projectID: Int
    let fileID: Int
    let required: Bool

    enum CodingKeys: String, CodingKey {
        case projectID
        case fileID
        case required
    }
}

/// CurseForge 整合包索引信息（转换后的格式）
struct CurseForgeIndexInfo {
    let gameVersion: String
    let loaderType: String
    let loaderVersion: String
    let modPackName: String
    let modPackVersion: String
    let author: String?
    let files: [CurseForgeManifestFile]
    let overridesPath: String?
}
