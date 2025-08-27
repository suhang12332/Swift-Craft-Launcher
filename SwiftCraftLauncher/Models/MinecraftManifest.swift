import Foundation

struct MinecraftVersionManifest: Codable {
    let arguments: Arguments
    let assetIndex: AssetIndex
    let assets: String
    let complianceLevel: Int
    let downloads: Downloads
    let id: String
    let javaVersion: JavaVersion
    let libraries: [Library]
    let logging: Logging
    let mainClass: String
    let minimumLauncherVersion: Int
    let releaseTime: String
    let time: String
    let type: String
}

struct Arguments: Codable {
    let game: [String]?
    let jvm: [String]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理 game 参数，可能不存在
        if container.contains(.game) {
            let gameArgs = try container.decode([ArgumentValue].self, forKey: .game)
            game = gameArgs.compactMap { arg in
                if case let .string(value) = arg {
                    return value
                }
                return nil // 丢弃 objectWithRules
            }
        } else {
            game = nil
        }
        
        // 处理 jvm 参数，可能不存在
        if container.contains(.jvm) {
            let jvmArgs = try container.decode([ArgumentValue].self, forKey: .jvm)
            jvm = jvmArgs.compactMap { arg in
                if case let .string(value) = arg {
                    return value
                }
                return nil // 丢弃 objectWithRules
            }
        } else {
            jvm = nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case game, jvm
    }
}

enum ArgumentValue: Codable {
    case string(String)
    case objectWithRules(ArgumentRuleObject)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .objectWithRules(try container.decode(ArgumentRuleObject.self))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .objectWithRules(let value): try container.encode(value)
        }
    }
}

struct ArgumentRuleObject: Codable {
    let rules: [Rule]
    let value: ArgumentValueArrayOrString
}

enum ArgumentValueArrayOrString: Codable {
    case string(String)
    case array([String])
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .array(try container.decode([String].self))
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }
}

struct Rule: Codable {
    let action: String
    let features: Features?
    let os: OS?
}

struct Features: Codable {
    let is_demo_user: Bool?
    let has_custom_resolution: Bool?
    let has_quick_plays_support: Bool?
    let is_quick_play_singleplayer: Bool?
    let is_quick_play_multiplayer: Bool?
    let is_quick_play_realms: Bool?
}

struct OS: Codable {
    let name: String?
    let version: String?
    let arch: String?
}

struct AssetIndex: Codable {
    let id: String
    let sha1: String
    let size: Int
    let totalSize: Int
    let url: URL
}

struct Downloads: Codable {
    let client: DownloadInfo
    let client_mappings: DownloadInfo?
    let server: DownloadInfo?
    let server_mappings: DownloadInfo?
}

struct DownloadInfo: Codable {
    let sha1: String
    let size: Int
    let url: URL
}

struct Library: Codable {
    var downloads: LibraryDownloads
    let name: String
    let rules: [Rule]?
    let natives: [String: String]?
    let extract: LibraryExtract?
    let url: URL?
}

struct LibraryDownloads: Codable {
    var artifact: LibraryArtifact
    let classifiers: [String: LibraryArtifact]?  // For native libraries

        // Handle potential missing keys during decoding
        enum CodingKeys: String, CodingKey {
            case artifact, classifiers
        }
}

struct LibraryArtifact: Codable {
    let path: String
    let sha1: String
    let size: Int
    var url: URL?
    
    // 自定义初始化器，用于直接创建实例
    init(path: String, sha1: String, size: Int, url: URL?) {
        self.path = path
        self.sha1 = sha1
        self.size = size
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        sha1 = try container.decode(String.self, forKey: .sha1)
        size = try container.decode(Int.self, forKey: .size)
        
        // 处理 URL，允许为空字符串
        let urlString = try container.decode(String.self, forKey: .url)
        if urlString.isEmpty {
            url = nil
        } else {
            url = URL(string: urlString)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(sha1, forKey: .sha1)
        try container.encode(size, forKey: .size)
        try container.encode(url?.absoluteString ?? "", forKey: .url)
    }
    
    enum CodingKeys: String, CodingKey {
        case path, sha1, size, url
    }
}

struct LibraryExtract: Codable {
    let exclude: [String]
}

struct Logging: Codable {
    let client: LoggingClient
}

struct LoggingClient: Codable {
    let argument: String
    let file: LoggingFile
    let type: String
}

struct LoggingFile: Codable {
    let id: String
    let sha1: String
    let size: Int
    let url: URL
}

struct JavaVersion: Codable {
    let component: String
    let majorVersion: Int
}

struct MojangVersionManifest: Codable {
    let latest: LatestVersions
    let versions: [MojangVersionInfo]
}

struct LatestVersions: Codable {
    let release: String
    let snapshot: String
}

struct MojangVersionInfo: Codable, Identifiable {
    let id: String
    let type: String
    let url: URL
    let time: String
    let releaseTime: String
}

struct DownloadedAssetIndex {
    let id: String
    let url: URL
    let sha1: String
    let totalSize: Int
    let objects: [String: AssetIndexData.AssetObject]
}

struct AssetIndexData: Codable {
    let objects: [String: AssetObject]
    struct AssetObject: Codable {
        let hash: String
        let size: Int
    }
}
