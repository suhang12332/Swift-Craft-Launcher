// MARK: - Fabric Loader API 响应模型
import Foundation

struct FabricLoader: Codable {
    let loader: LoaderInfo
    let intermediary: IntermediaryInfo
    let launcherMeta: LauncherMeta
    
    struct LoaderInfo: Codable {
        let separator: String
        let build: Int
        let maven: String
        let version: String
        let stable: Bool
    }
    struct IntermediaryInfo: Codable {
        let maven: String
        let version: String
        let stable: Bool
    }
    struct LauncherMeta: Codable {
        let version: Int
        let min_java_version: Int
        let libraries: Libraries
        let mainClass: MainClass
        
        struct Libraries: Codable {
            let client: [Library]
            let common: [Library]
            let server: [Library]
            let development: [Library]?
        }
        struct Library: Codable {
            let name: String
            let url: String
            let md5: String
            let sha1: String
            let sha256: String
            let sha512: String
            let size: Int
        }
        struct MainClass: Codable {
            let client: String
            let server: String
        }
    }
} 