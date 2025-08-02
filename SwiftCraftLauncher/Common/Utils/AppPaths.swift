import Foundation

struct AppPaths {
    
    static var launcherSupportDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent(Bundle.main.appName)
    }
    static var metaDirectory: URL? {
        launcherSupportDirectory?.appendingPathComponent("meta")
    }
    static var librariesDirectory: URL? {
        metaDirectory?.appendingPathComponent("libraries")
    }
    static var nativesDirectory: URL? {
        metaDirectory?.appendingPathComponent("natives")
    }
    static var assetsDirectory: URL? {
        metaDirectory?.appendingPathComponent("assets")
    }
    static var versionsDirectory: URL? {
        metaDirectory?.appendingPathComponent("versions")
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
    /// 全局缓存文件路径
    static var appCache: URL? {
        launcherSupportDirectory?.appendingPathComponent("cache")
    }
}
