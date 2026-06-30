//
//  MinecraftManifest.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A Minecraft version manifest containing full launch configuration.
struct MinecraftVersionManifest: Codable {
    let arguments: Arguments
    let assetIndex: AssetIndex
    let assets: String
    let complianceLevel: Int?
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

    enum CodingKeys: String, CodingKey {
        case arguments, assetIndex, assets, downloads, id, javaVersion, libraries, logging, mainClass, minimumLauncherVersion, releaseTime, time, type
        case complianceLevel = "complianceLevel"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        arguments = try container.decode(Arguments.self, forKey: .arguments)
        assetIndex = try container.decode(AssetIndex.self, forKey: .assetIndex)
        assets = try container.decode(String.self, forKey: .assets)
        complianceLevel = try container.decodeIfPresent(Int.self, forKey: .complianceLevel)
        downloads = try container.decode(Downloads.self, forKey: .downloads)
        id = try container.decode(String.self, forKey: .id)
        javaVersion = try container.decode(JavaVersion.self, forKey: .javaVersion)
        libraries = try container.decode([Library].self, forKey: .libraries)
        logging = try container.decode(Logging.self, forKey: .logging)
        mainClass = try container.decode(String.self, forKey: .mainClass)
        minimumLauncherVersion = try container.decode(Int.self, forKey: .minimumLauncherVersion)
        releaseTime = try container.decode(String.self, forKey: .releaseTime)
        time = try container.decode(String.self, forKey: .time)
        type = try container.decode(String.self, forKey: .type)
    }
}

/// Game and JVM arguments for a Minecraft version.
struct Arguments: Codable {
    let game: [String]?
    let jvm: [String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.game) {
            let gameArgs = try container.decode([ArgumentValue].self, forKey: .game)
            game = gameArgs.compactMap { arg in
                if case let .string(value) = arg {
                    return value
                }
                return nil
            }
        } else {
            game = nil
        }

        if container.contains(.jvm) {
            let jvmArgs = try container.decode([ArgumentValue].self, forKey: .jvm)
            jvm = jvmArgs.compactMap { arg in
                if case let .string(value) = arg {
                    return value
                }
                return nil
            }
        } else {
            jvm = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case game, jvm
    }
}

/// A value that can be either a plain string or a conditional rule object.
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

/// A conditional argument with rules that determine when it applies.
struct ArgumentRuleObject: Codable {
    let rules: [Rule]
    let value: ArgumentValueArrayOrString
}

/// A value that can be either a string or an array of strings.
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

/// A conditional rule that determines whether an argument or library applies.
struct Rule: Codable {
    let action: String
    let features: Features?
    let os: OperatingSystem?
}

/// Feature flags used in conditional rules.
struct Features: Codable {
    let is_demo_user: Bool
    let has_custom_resolution: Bool
    let has_quick_plays_support: Bool
    let is_quick_play_singleplayer: Bool
    let is_quick_play_multiplayer: Bool
    let is_quick_play_realms: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

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

/// Operating system information used in conditional rules.
struct OperatingSystem: Codable {
    let name: String?
    let version: String?
    let arch: String?
}

/// An asset index entry describing a downloadable asset index file.
struct AssetIndex: Codable {
    let id: String
    let sha1: String
    let size: Int
    let totalSize: Int
    let url: URL
}

/// Download information for client and server artifacts.
struct Downloads: Codable {
    let client: DownloadInfo
    let client_mappings: DownloadInfo?
    let server: DownloadInfo?
    let server_mappings: DownloadInfo?
}

/// A downloadable artifact with integrity information.
struct DownloadInfo: Codable {
    let sha1: String
    let size: Int
    let url: URL
}

/// A library dependency required by a Minecraft version.
struct Library: Codable {
    var downloads: LibraryDownloads
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
        downloads = try container.decode(LibraryDownloads.self, forKey: .downloads)
        name = try container.decode(String.self, forKey: .name)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules)
        natives = try container.decodeIfPresent([String: String].self, forKey: .natives)
        extract = try container.decodeIfPresent(LibraryExtract.self, forKey: .extract)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        includeInClasspath = try container.decodeIfPresent(Bool.self, forKey: .includeInClasspath) ?? true
        downloadable = try container.decodeIfPresent(Bool.self, forKey: .downloadable) ?? true
    }
}

/// Downloadable artifacts for a library, including native classifiers.
struct LibraryDownloads: Codable {
    var artifact: LibraryArtifact
    let classifiers: [String: LibraryArtifact]?

    enum CodingKeys: String, CodingKey {
        case artifact, classifiers
    }
}

/// A single downloadable library artifact.
struct LibraryArtifact: Codable {
    let path: String?
    let sha1: String
    let size: Int
    var url: URL?

    init(path: String?, sha1: String, size: Int, url: URL?) {
        self.path = path
        self.sha1 = sha1
        self.size = size
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        path = try container.decodeIfPresent(String.self, forKey: .path)
        sha1 = try container.decode(String.self, forKey: .sha1)
        size = try container.decode(Int.self, forKey: .size)

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

/// Files to exclude when extracting a library archive.
struct LibraryExtract: Codable {
    let exclude: [String]
}

/// Logging configuration for the Minecraft client.
struct Logging: Codable {
    let client: LoggingClient
}

/// Client-side logging configuration details.
struct LoggingClient: Codable {
    let argument: String
    let file: LoggingFile
    let type: String
}

/// A logging configuration file reference.
struct LoggingFile: Codable {
    let id: String
    let sha1: String
    let size: Int
    let url: URL
}

/// Java version requirements for a Minecraft version.
struct JavaVersion: Codable {
    let component: String
    let majorVersion: Int
}

/// The top-level Mojang version manifest.
struct MojangVersionManifest: Codable {
    let latest: LatestVersions
    let versions: [MojangVersionInfo]
}

/// The latest release and snapshot version identifiers.
struct LatestVersions: Codable {
    let release: String
    let snapshot: String
}

/// A version entry in the Mojang version manifest.
struct MojangVersionInfo: Codable, Identifiable {
    let id: String
    let type: String
    let url: URL
    let time: String
    let releaseTime: String
}

/// A downloaded asset index containing object mappings.
struct DownloadedAssetIndex {
    let id: String
    let url: URL
    let sha1: String
    let totalSize: Int
    let objects: [String: AssetIndexData.AssetObject]
}

/// Asset index data mapping asset names to their downloadable objects.
struct AssetIndexData: Codable {
    let objects: [String: AssetObject]

    struct AssetObject: Codable {
        let hash: String
        let size: Int
    }
}
