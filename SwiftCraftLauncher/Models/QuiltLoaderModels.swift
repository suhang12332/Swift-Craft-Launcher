import Foundation

struct QuiltLoaderResponse: Codable {
    struct Loader: Codable {
        let separator: String?
        let build: Int?
        let maven: String
        let version: String
    }
    struct Hashed: Codable {
        let maven: String
        let version: String
    }
    struct Intermediary: Codable {
        let maven: String
        let version: String
    }
    struct Library: Codable {
        let name: String
        let url: String
    }
    struct Libraries: Codable {
        let client: [Library]
        let common: [Library]
        let server: [Library]
        let development: [Library]?
    }
    struct MainClass: Codable {
        let client: String
        let server: String
        let serverLauncher: String?
    }
    struct LauncherMeta: Codable {
        let version: Int
        let min_java_version: Int?
        let libraries: Libraries
        let mainClass: MainClass
    }
    let loader: Loader
    let hashed: Hashed?
    let intermediary: Intermediary?
    let launcherMeta: LauncherMeta
} 