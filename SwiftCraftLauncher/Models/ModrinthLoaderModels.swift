//
//  ModrinthLoaderModels.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/7/27.
//

import Foundation



// MARK: - ModrinthLoader
struct ModrinthLoader: Codable {
    let id, inheritsFrom, releaseTime, time: String
    let mainClass: String
    let arguments: Arguments
    var libraries: [ModrinthLoaderLibrary]
    let type: String
    var version: String?
    
    // 忽略这些字段，不需要反序列化
    private let data: String?
    private let processors: String?
    
    enum CodingKeys: String, CodingKey {
        case id, inheritsFrom, releaseTime, time, mainClass, arguments, libraries, type, version
        // 不包含 data 和 processors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        inheritsFrom = try container.decode(String.self, forKey: .inheritsFrom)
        releaseTime = try container.decode(String.self, forKey: .releaseTime)
        time = try container.decode(String.self, forKey: .time)
        mainClass = try container.decode(String.self, forKey: .mainClass)
        arguments = try container.decode(Arguments.self, forKey: .arguments)
        libraries = try container.decode([ModrinthLoaderLibrary].self, forKey: .libraries)
        type = try container.decode(String.self, forKey: .type)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        
        // 过滤掉 downloads 为 nil 的库
        // libraries = libraries.filter { $0.downloads != nil }
        
        // 忽略 data 和 processors 字段
        data = nil
        processors = nil
    }
}

// MARK: - ModrinthLoaderLibrary
struct ModrinthLoaderLibrary: Codable {
    var downloads: LibraryDownloads?
    var name: String
    var includeInClasspath: Bool
    var downloadable: Bool
    var skip: Bool?
    var url: URL?
    
    // 自定义初始化器，用于直接创建实例
    init(downloads: LibraryDownloads?, name: String, includeInClasspath: Bool, downloadable: Bool,skip: Bool) {
        self.downloads = downloads
        self.name = name
        self.includeInClasspath = includeInClasspath
        self.downloadable = downloadable
        self.skip = skip
    }
    
    enum CodingKeys: String, CodingKey {
        case name, downloadable,downloads,url
        case includeInClasspath = "include_in_classpath"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        downloadable = try container.decode(Bool.self, forKey: .downloadable)
        includeInClasspath = try container.decode(Bool.self, forKey: .includeInClasspath)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        downloads = try container.decodeIfPresent(LibraryDownloads.self, forKey: .downloads)
    }
}

// MARK: - ModrinthLoaderVersion
struct ModrinthLoaderVersion: Decodable {
    let gameVersions: [LoaderVersion]
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
