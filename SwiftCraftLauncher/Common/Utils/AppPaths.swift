import Foundation

struct AppPaths {
    
    static var launcherSupportDirectory: URL {
//        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//            return nil
//        }
        return .applicationSupportDirectory.appendingPathComponent(Bundle.main.appName)
    }
    static var metaDirectory: URL {
        launcherSupportDirectory.appendingPathComponent("meta")
    }
    static var librariesDirectory: URL {
        metaDirectory.appendingPathComponent("libraries")
    }
    static var nativesDirectory: URL {
        metaDirectory.appendingPathComponent("natives")
    }
    static var assetsDirectory: URL {
        metaDirectory.appendingPathComponent("assets")
    }
    static var versionsDirectory: URL {
        metaDirectory.appendingPathComponent("versions")
    }
    static var profileRootDirectory: URL? {
        let customPath = GeneralSettingsManager.shared.launcherWorkingDirectory
        guard !customPath.isEmpty else { return nil }
        
        let baseURL = URL(fileURLWithPath: customPath, isDirectory: true)
        return baseURL.appendingPathComponent("profiles", isDirectory: true)
    }
    static func profileDirectory(gameName: String) -> URL? {
        profileRootDirectory?.appendingPathComponent(gameName)
    }
    static func savesDirectory(gameName: String) -> URL? {
        profileRootDirectory?.appendingPathComponent(gameName).appendingPathComponent("saves",isDirectory: true)
    }
    static func modsDirectory(gameName: String) -> URL? {
        profileDirectory(gameName: gameName)?.appendingPathComponent("mods")
    }
    static func datapacksDirectory(gameName: String) -> URL? {
        profileDirectory(gameName: gameName)?.appendingPathComponent("datapacks")
    }
    static func shaderpacksDirectory(gameName: String) -> URL? {
        profileDirectory(gameName: gameName)?.appendingPathComponent("shaderpacks")
    }
    static func resourcepacksDirectory(gameName: String) -> URL? {
        profileDirectory(gameName: gameName)?.appendingPathComponent("resourcepacks")
    }
    
    static let profileSubdirectories = ["shaderpacks", "resourcepacks", "mods", "datapacks", "crash-reports"]
    
    /// 日志文件目录 - 使用系统标准日志目录
    static var logsDirectory: URL? {
        guard let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return libraryDirectory.appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(Bundle.main.appName, isDirectory: true)
    }
}

extension AppPaths {
    static func resourceDirectory(for type: String, gameName: String) -> URL? {
        switch type.lowercased() {
        case "mod": return modsDirectory(gameName: gameName)
        case "datapack": return datapacksDirectory(gameName: gameName)
        case "shader": return shaderpacksDirectory(gameName: gameName)
        case "resourcepack": return resourcepacksDirectory(gameName: gameName)
        default: return nil
        }
    }
    /// 全局缓存文件路径 - 使用系统标准缓存目录
    static var appCache: URL {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            // 如果无法获取系统缓存目录，则回退到 Application Support 下的 cache 目录
            return launcherSupportDirectory.appendingPathComponent("cache")
        }
        return cachesDirectory.appendingPathComponent(Bundle.main.identifier)
    }
}
