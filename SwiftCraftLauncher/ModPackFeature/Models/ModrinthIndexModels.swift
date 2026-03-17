import Foundation

// MARK: - Modrinth Index Models

struct ModrinthIndex: Codable {
    let formatVersion: Int
    let game: String
    let versionId: String
    let name: String
    let summary: String?
    let files: [ModrinthIndexFile]
    let dependencies: ModrinthIndexDependencies

    enum CodingKeys: String, CodingKey {
        case formatVersion = "formatVersion"
        case game
        case versionId = "versionId"
        case name
        case summary
        case files
        case dependencies
    }
}

// MARK: - File Hashes (优化内存使用)
/// 优化的文件哈希结构，使用结构体替代字典以减少内存占用
/// 常用哈希（sha1, sha512）作为属性存储，其他哈希存储在可选字典中
struct ModrinthIndexFileHashes: Codable {
    /// SHA1 哈希（最常用）
    let sha1: String?
    /// SHA512 哈希（次常用）
    let sha512: String?
    /// 其他哈希类型（不常用，延迟存储）
    let other: [String: String]?

    /// 从字典创建（用于 JSON 解码）
    init(from dict: [String: String]) {
        self.sha1 = dict["sha1"]
        self.sha512 = dict["sha512"]

        // 只存储非标准哈希
        var otherDict: [String: String] = [:]
        for (key, value) in dict {
            if key != "sha1" && key != "sha512" {
                otherDict[key] = value
            }
        }
        self.other = otherDict.isEmpty ? nil : otherDict
    }

    /// 自定义解码，从 JSON 字典解码
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        self.init(from: dict)
    }

    /// 编码为字典格式（用于 JSON 编码）
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var dict: [String: String] = [:]

        if let sha1 = sha1 {
            dict["sha1"] = sha1
        }
        if let sha512 = sha512 {
            dict["sha512"] = sha512
        }
        if let other = other {
            dict.merge(other) { _, new in new }
        }

        try container.encode(dict)
    }

    /// 字典访问兼容性（向后兼容）
    subscript(key: String) -> String? {
        switch key {
        case "sha1": return sha1
        case "sha512": return sha512
        default: return other?[key]
        }
    }
}

struct ModrinthIndexFile: Codable {
    let path: String
    let hashes: ModrinthIndexFileHashes
    let downloads: [String]
    let fileSize: Int
    let env: ModrinthIndexFileEnv?
    let source: FileSource?
    // CurseForge 特有字段，用于延迟获取文件详情
    let curseForgeProjectId: Int?
    let curseForgeFileId: Int?

    enum CodingKeys: String, CodingKey {
        case path
        case hashes
        case downloads
        case fileSize = "fileSize"
        case env
        case source
        case curseForgeProjectId
        case curseForgeFileId
    }

    // 为兼容性提供默认初始化器
    init(
        path: String,
        hashes: ModrinthIndexFileHashes,
        downloads: [String],
        fileSize: Int,
        env: ModrinthIndexFileEnv? = nil,
        source: FileSource? = nil,
        curseForgeProjectId: Int? = nil,
        curseForgeFileId: Int? = nil
    ) {
        self.path = path
        self.hashes = hashes
        self.downloads = downloads
        self.fileSize = fileSize
        self.env = env
        self.source = source
        self.curseForgeProjectId = curseForgeProjectId
        self.curseForgeFileId = curseForgeFileId
    }

    // 兼容旧版本字典格式的初始化器
    init(
        path: String,
        hashes: [String: String],
        downloads: [String],
        fileSize: Int,
        env: ModrinthIndexFileEnv? = nil,
        source: FileSource? = nil,
        curseForgeProjectId: Int? = nil,
        curseForgeFileId: Int? = nil
    ) {
        self.path = path
        self.hashes = ModrinthIndexFileHashes(from: hashes)
        self.downloads = downloads
        self.fileSize = fileSize
        self.env = env
        self.source = source
        self.curseForgeProjectId = curseForgeProjectId
        self.curseForgeFileId = curseForgeFileId
    }
}

enum FileSource: String, Codable {
    case modrinth = "modrinth"
    case curseforge = "curseforge"
}

struct ModrinthIndexFileEnv: Codable {
    let client: String?
    let server: String?
}

struct ModrinthIndexDependencies: Codable {
    let minecraft: String?
    let forgeLoader: String?
    let fabricLoader: String?
    let quiltLoader: String?
    let neoforgeLoader: String?
    // 添加不带 -loader 后缀的属性
    let forge: String?
    let fabric: String?
    let quilt: String?
    let neoforge: String?
    let dependencies: [ModrinthIndexProjectDependency]?

    enum CodingKeys: String, CodingKey {
        case minecraft
        case forgeLoader = "forge-loader"
        case fabricLoader = "fabric-loader"
        case quiltLoader = "quilt-loader"
        case neoforgeLoader = "neoforge-loader"
        case forge
        case fabric
        case quilt
        case neoforge
        case dependencies
    }
}

struct ModrinthIndexProjectDependency: Codable {
    let projectId: String?
    let versionId: String?
    let dependencyType: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case versionId = "version_id"
        case dependencyType = "dependency_type"
    }
}

// MARK: - Modrinth Index Info
struct ModrinthIndexInfo {
    let gameVersion: String
    let loaderType: String
    let loaderVersion: String
    let modPackName: String
    let modPackVersion: String
    let summary: String?
    let files: [ModrinthIndexFile]
    let dependencies: [ModrinthIndexProjectDependency]
    let source: FileSource

    init(
        gameVersion: String,
        loaderType: String,
        loaderVersion: String,
        modPackName: String,
        modPackVersion: String,
        summary: String?,
        files: [ModrinthIndexFile],
        dependencies: [ModrinthIndexProjectDependency],
        source: FileSource = .modrinth
    ) {
        self.gameVersion = gameVersion
        self.loaderType = loaderType
        self.loaderVersion = loaderVersion
        self.modPackName = modPackName
        self.modPackVersion = modPackVersion
        self.summary = summary
        self.files = files
        self.dependencies = dependencies
        self.source = source
    }
}
