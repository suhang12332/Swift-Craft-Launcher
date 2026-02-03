//
//  ModrinthLoaderModels.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/7/27.
//

import Foundation

// MARK: - SidedDataEntry
struct SidedDataEntry: Codable {
    let client: String
    let server: String
}

// MARK: - Processor
struct Processor: Codable {
    let sides: [String]?
    let jar: String?
    let classpath: [String]?
    let args: [String]?
    let outputs: [String: String]?

    enum CodingKeys: String, CodingKey {
        case sides, jar, classpath, args, outputs
    }
}

// MARK: - LoaderVersion
struct LoaderVersion: Decodable {
    let id: String
    let stable: Bool
    let loaders: [LoaderInfo]
}

// MARK: - LoaderInfo
struct LoaderInfo: Decodable {
    let id: String
    let url: String
    let stable: Bool
}

// MARK: - ModrinthLoaderVersion
struct ModrinthLoaderVersion: Decodable {
    let gameVersions: [LoaderVersion]
}

// MARK: - ModrinthLoader
struct ModrinthLoader: Codable {
    let mainClass: String
    let arguments: Arguments
    var libraries: [ModrinthLoaderLibrary]
    var version: String?
    let processors: [Processor]?
    let data: [String: SidedDataEntry]?

    enum CodingKeys: String, CodingKey {
        case mainClass, arguments, libraries, version, processors, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainClass = try container.decode(String.self, forKey: .mainClass)
        arguments = try container.decode(Arguments.self, forKey: .arguments)
        libraries = try container.decode(
            [ModrinthLoaderLibrary].self,
            forKey: .libraries
        )
        version = try container.decodeIfPresent(String.self, forKey: .version)
        processors = try container.decodeIfPresent(
            [Processor].self,
            forKey: .processors
        )
        data = try container.decodeIfPresent(
            [String: SidedDataEntry].self,
            forKey: .data
        )
    }
}

// MARK: - ModrinthLoaderLibrary
struct ModrinthLoaderLibrary: Codable {
    var downloads: LibraryDownloads?
    var name: String
    var includeInClasspath: Bool
    var downloadable: Bool
    var url: URL?

    // 自定义初始化器，用于直接创建实例
    init(
        downloads: LibraryDownloads?,
        name: String,
        includeInClasspath: Bool,
        downloadable: Bool
    ) {
        self.downloads = downloads
        self.name = name
        self.includeInClasspath = includeInClasspath
        self.downloadable = downloadable
    }

    enum CodingKeys: String, CodingKey {
        case name, downloadable, downloads, url
        case includeInClasspath = "include_in_classpath"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        downloadable = try container.decode(Bool.self, forKey: .downloadable)
        includeInClasspath = try container.decode(
            Bool.self,
            forKey: .includeInClasspath
        )
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        downloads = try container.decodeIfPresent(
            LibraryDownloads.self,
            forKey: .downloads
        )
    }
}
