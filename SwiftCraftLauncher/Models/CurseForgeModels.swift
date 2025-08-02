 import Foundation

struct CurseForgeSearchResult: Codable {
    let data: [CurseForgeMod]
}

struct CurseForgeMod: Codable {
    let id: Int
    let name: String
    let summary: String
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