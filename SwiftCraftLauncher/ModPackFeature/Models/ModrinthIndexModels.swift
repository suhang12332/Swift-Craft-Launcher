//
//  ModrinthIndexModels.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents a Modrinth mod pack index file.
struct ModrinthIndex: Codable {
    let formatVersion: Int
    let game: String
    let versionId: String
    let name: String
    let summary: String?
    let files: [ModrinthIndexFile]
    let dependencies: ModrinthIndexDependencies

    enum CodingKeys: String, CodingKey {
        case formatVersion
        case game
        case versionId
        case name
        case summary
        case files
        case dependencies
    }
}

/// Stores file hashes with commonly used hashes as properties.
struct ModrinthIndexFileHashes: Codable {
    /// The SHA-1 hash.
    let sha1: String?
    /// The SHA-512 hash.
    let sha512: String?
    /// Additional hash types.
    let other: [String: String]?

    /// Creates an instance from a dictionary.
    init(from dict: [String: String]) {
        sha1 = dict["sha1"]
        sha512 = dict["sha512"]

        var otherDict: [String: String] = [:]
        for (key, value) in dict {
            if key != "sha1", key != "sha512" {
                otherDict[key] = value
            }
        }
        other = otherDict.isEmpty ? nil : otherDict
    }

    /// Decodes the hashes from a JSON dictionary.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        self.init(from: dict)
    }

    /// Encodes the hashes as a JSON dictionary.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var dict: [String: String] = [:]

        if let sha1 {
            dict["sha1"] = sha1
        }
        if let sha512 {
            dict["sha512"] = sha512
        }
        if let other {
            dict.merge(other) { _, new in new }
        }

        try container.encode(dict)
    }

    /// Provides dictionary-style access to hashes by type name.
    subscript(key: String) -> String? {
        switch key {
        case "sha1": return sha1
        case "sha512": return sha512
        default: return other?[key]
        }
    }
}

/// A file entry in the mod pack index.
struct ModrinthIndexFile: Codable {
    let path: String
    let hashes: ModrinthIndexFileHashes
    let downloads: [String]
    let fileSize: Int
    let env: ModrinthIndexFileEnv?
    let source: FileSource?
    /// The CurseForge project identifier, if sourced from CurseForge.
    let curseForgeProjectId: Int?
    /// The CurseForge file identifier, if sourced from CurseForge.
    let curseForgeFileId: Int?

    enum CodingKeys: String, CodingKey {
        case path
        case hashes
        case downloads
        case fileSize
        case env
        case source
        case curseForgeProjectId
        case curseForgeFileId
    }

    init(
        path: String,
        hashes: ModrinthIndexFileHashes,
        downloads: [String],
        fileSize: Int,
        env: ModrinthIndexFileEnv? = nil,
        source: FileSource? = nil,
        curseForgeProjectId: Int? = nil,
        curseForgeFileId: Int? = nil,
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
}

/// Identifies the source platform of a mod file.
enum FileSource: String, Codable {
    case modrinth
    case curseforge
}

/// Environment compatibility for a mod file.
struct ModrinthIndexFileEnv: Codable {
    let client: String?
    let server: String?
}

/// Dependencies required by the mod pack.
struct ModrinthIndexDependencies: Codable {
    let minecraft: String?
    let forgeLoader: String?
    let fabricLoader: String?
    let quiltLoader: String?
    let neoforgeLoader: String?
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

/// A project-level dependency for the mod pack.
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

/// Contains parsed mod pack index information for installation.
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
        source: FileSource = .modrinth,
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
