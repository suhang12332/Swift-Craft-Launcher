import Foundation

/// 兼容 Forge version.json 的完整结构体
struct ForgeLoader: Codable {
    var version: String?
    let id: String
    let time: String
    let releaseTime: String
    let inheritsFrom: String?
    let type: String
    let logging: [String: ForgeLoggingConfig]? // 可选，兼容空对象
    let mainClass: String
    var libraries: [ForgeLibrary]
    let arguments: ForgeArguments? // 新增，兼容 arguments 字段
    // 允许 _comment 字段被忽略
}

struct ForgeArguments: Codable {
    let game: [String]?
    let jvm: [String]?
}

struct ForgeLoggingConfig: Codable {}

struct ForgeLoggingFileConfig: Codable {
    let argument: String
    let file: ForgeLoggingFile
    let type: String
}

struct ForgeLoggingFile: Codable {
    let id: String
    let sha1: String
    let size: Int
    let url: String
}

struct ForgeLibrary: Codable {
    let name: String
    var downloads: ForgeLibraryDownloads
}

struct ForgeLibraryDownloads: Codable {
    var artifact: ForgeLibraryArtifact
}

struct ForgeLibraryArtifact: Codable {
    let path: String
    var url: String
    let sha1: String
    let size: Int?
}

struct ForgeLibraryExtract: Codable {
    let exclude: [String]
    let include: [String]
} 
