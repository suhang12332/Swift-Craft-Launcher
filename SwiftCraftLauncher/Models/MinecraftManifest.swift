import Foundation

struct MinecraftVersionManifest: Codable {
    /// 新版格式：game/jvm 数组；旧版无此字段，改用 minecraftArguments。
    let arguments: Arguments?
    let assetIndex: AssetIndex
    let assets: String
    let complianceLevel: Int?
    let downloads: Downloads
    let id: String
    /// 旧版可能缺失，默认按 Java 8 (jre-legacy) 处理。
    let javaVersion: JavaVersion?
    let libraries: [Library]
    /// 旧版可能缺失，缺失时不下载 logging 配置。
    let logging: Logging?
    let mainClass: String
    /// 旧版格式：整行参数字符串；与 arguments 二选一，arguments 优先。
    let minecraftArguments: String?
    /// 旧版可能缺失，缺省为 0。
    let minimumLauncherVersion: Int
    let releaseTime: String
    let time: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case arguments, assetIndex, asset_index, assets, complianceLevel, downloads, id, javaVersion, libraries, logging, mainClass
        case minecraftArguments
        case minimumLauncherVersion, releaseTime, time, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        arguments = try container.decodeIfPresent(Arguments.self, forKey: .arguments)
        let a1 = try container.decodeIfPresent(AssetIndex.self, forKey: .assetIndex)
        let a2 = try container.decodeIfPresent(AssetIndex.self, forKey: .asset_index)
        guard let ai = a1 ?? a2 else {
            throw DecodingError.keyNotFound(CodingKeys.assetIndex, DecodingError.Context(codingPath: container.codingPath, debugDescription: "assetIndex / asset_index 均缺失"))
        }
        assetIndex = ai
        assets = try container.decode(String.self, forKey: .assets)
        complianceLevel = try container.decodeIfPresent(Int.self, forKey: .complianceLevel)
        downloads = try container.decode(Downloads.self, forKey: .downloads)
        id = try container.decode(String.self, forKey: .id)
        javaVersion = try container.decodeIfPresent(JavaVersion.self, forKey: .javaVersion)
        libraries = try container.decode([Library].self, forKey: .libraries)
        logging = try container.decodeIfPresent(Logging.self, forKey: .logging)
        mainClass = try container.decode(String.self, forKey: .mainClass)
        minecraftArguments = try container.decodeIfPresent(String.self, forKey: .minecraftArguments)
        minimumLauncherVersion = try container.decodeIfPresent(Int.self, forKey: .minimumLauncherVersion) ?? 0
        releaseTime = try container.decode(String.self, forKey: .releaseTime)
        time = try container.decode(String.self, forKey: .time)
        type = try container.decode(String.self, forKey: .type)
    }

    /// 解析旧版 minecraft_arguments 字符串为 [String]，按空格分割；占位符由调用方替换。
    static func parseMinecraftArguments(_ s: String) -> [String] {
        s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(arguments, forKey: .arguments)
        try container.encode(assetIndex, forKey: .assetIndex)
        try container.encode(assets, forKey: .assets)
        try container.encodeIfPresent(complianceLevel, forKey: .complianceLevel)
        try container.encode(downloads, forKey: .downloads)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(javaVersion, forKey: .javaVersion)
        try container.encode(libraries, forKey: .libraries)
        try container.encodeIfPresent(logging, forKey: .logging)
        try container.encode(mainClass, forKey: .mainClass)
        try container.encodeIfPresent(minecraftArguments, forKey: .minecraftArguments)
        try container.encode(minimumLauncherVersion, forKey: .minimumLauncherVersion)
        try container.encode(releaseTime, forKey: .releaseTime)
        try container.encode(time, forKey: .time)
        try container.encode(type, forKey: .type)
    }
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
    let os: OperatingSystem?
}

struct Features: Codable {
    let is_demo_user: Bool
    let has_custom_resolution: Bool
    let has_quick_plays_support: Bool
    let is_quick_play_singleplayer: Bool
    let is_quick_play_multiplayer: Bool
    let is_quick_play_realms: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle both missing keys and null values
        is_demo_user = (try? container.decodeIfPresent(Bool.self, forKey: .is_demo_user)) ?? false
        has_custom_resolution = (try? container.decodeIfPresent(Bool.self, forKey: .has_custom_resolution)) ?? false
        has_quick_plays_support = (try? container.decodeIfPresent(Bool.self, forKey: .has_quick_plays_support)) ?? false
        is_quick_play_singleplayer = (try? container.decodeIfPresent(Bool.self, forKey: .is_quick_play_singleplayer)) ?? false
        is_quick_play_multiplayer = (try? container.decodeIfPresent(Bool.self, forKey: .is_quick_play_multiplayer)) ?? false
        is_quick_play_realms = (try? container.decodeIfPresent(Bool.self, forKey: .is_quick_play_realms)) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case is_demo_user, has_custom_resolution, has_quick_plays_support
        case is_quick_play_singleplayer, is_quick_play_multiplayer, is_quick_play_realms
    }
}

struct OperatingSystem: Codable {
    let name: String?
    let version: String?
    let arch: String?
}

struct AssetIndex: Codable {
    let id: String
    let sha1: String
    let size: Int
    /// 老版本 assetIndex 可能无此字段。
    let totalSize: Int?
    let url: URL

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sha1 = try c.decode(String.self, forKey: .sha1)
        size = try c.decode(Int.self, forKey: .size)
        totalSize = try c.decodeIfPresent(Int.self, forKey: .totalSize)
        url = try c.decode(URL.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sha1, forKey: .sha1)
        try c.encode(size, forKey: .size)
        try c.encodeIfPresent(totalSize, forKey: .totalSize)
        try c.encode(url, forKey: .url)
    }

    private enum CodingKeys: String, CodingKey { case id, sha1, size, totalSize, url }
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
    /// 老版本可能无此字段，仅用 name+url；缺失时不予下载与加入 classpath。
    var downloads: LibraryDownloads?
    let name: String
    let rules: [Rule]?
    let natives: [String: String]?
    let extract: LibraryExtract?
    let url: URL?
    let includeInClasspath: Bool
    let downloadable: Bool

    enum CodingKeys: String, CodingKey {
        case downloads, name, rules, natives, extract, url
        case includeInClasspath = "include_in_classpath"
        case downloadable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloads = try container.decodeIfPresent(LibraryDownloads.self, forKey: .downloads)
        name = try container.decode(String.self, forKey: .name)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules)
        natives = try container.decodeIfPresent([String: String].self, forKey: .natives)
        extract = try container.decodeIfPresent(LibraryExtract.self, forKey: .extract)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        includeInClasspath = try container.decodeIfPresent(Bool.self, forKey: .includeInClasspath) ?? true
        downloadable = try container.decodeIfPresent(Bool.self, forKey: .downloadable) ?? true
    }
}

struct LibraryDownloads: Codable {
    /// 某些库可能只有 classifiers 而没有 artifact（如仅原生库）
    var artifact: LibraryArtifact?
    let classifiers: [String: LibraryArtifact]?  // For native libraries

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        artifact = try container.decodeIfPresent(LibraryArtifact.self, forKey: .artifact)
        classifiers = try container.decodeIfPresent([String: LibraryArtifact].self, forKey: .classifiers)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(artifact, forKey: .artifact)
        try container.encodeIfPresent(classifiers, forKey: .classifiers)
    }

    enum CodingKeys: String, CodingKey {
        case artifact, classifiers
    }
}

struct LibraryArtifact: Codable {
    let path: String?
    let sha1: String
    let size: Int
    var url: URL?

    // 自定义初始化器，用于直接创建实例
    init(path: String?, sha1: String, size: Int, url: URL?) {
        self.path = path
        self.sha1 = sha1
        self.size = size
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // path 字段可能不存在（特别是对于 LWJGL 原生库）
        path = try container.decodeIfPresent(String.self, forKey: .path)
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
        try container.encodeIfPresent(path, forKey: .path)
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

    init(component: String, majorVersion: Int) {
        self.component = component
        self.majorVersion = majorVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        component = try c.decodeIfPresent(String.self, forKey: .component) ?? "jre-legacy"
        majorVersion = try c.decodeIfPresent(Int.self, forKey: .majorVersion) ?? 8
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(component, forKey: .component)
        try c.encode(majorVersion, forKey: .majorVersion)
    }

    private enum CodingKeys: String, CodingKey { case component, majorVersion }
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
