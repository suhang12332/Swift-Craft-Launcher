import Foundation

enum AppPaths {
    static var launcherSupportDirectory: URL {
    // guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
    //     return nil
    // }
        .applicationSupportDirectory.appendingPathComponent(Bundle.main.appName)
    }

    /// 认证相关文件根目录（Application Support/.../auth）
    static var authDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.auth, isDirectory: true)
    }

    static var runtimeDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.runtime)
    }

    /// 指定版本的 Java 可执行文件路径（runtime 目录下的 jre.bundle）
    static func javaExecutablePath(version: String) -> String {
        runtimeDirectory.appendingPathComponent(version).appendingPathComponent("jre.bundle/Contents/Home/bin/java").path
    }

    static var metaDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.meta)
    }
    static var librariesDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.libraries)
    }
    static var nativesDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.natives)
    }
    static var assetsDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.assets)
    }
    static var versionsDirectory: URL {
        metaDirectory.appendingPathComponent(AppConstants.DirectoryNames.versions)
    }
    static var profileRootDirectory: URL {
        let customPath = AppServices.generalSettingsManager.launcherWorkingDirectory
        let workingDirectory = customPath.isEmpty ? launcherSupportDirectory.path : customPath

        let baseURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        return baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
    }

    static func profileDirectory(gameName: String) -> URL {
        profileRootDirectory.appendingPathComponent(gameName)
    }

    /// 某个游戏实例的 options.txt 路径
    static func optionsFile(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.option)
    }

    static func modsDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.mods)
    }

    static func datapacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.datapacks)
    }

    static func shaderpacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.shaderpacks)
    }

    static func resourcepacksDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.resourcepacks)
    }

    static func schematicsDirectory(gameName: String) -> URL {
        profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.schematics, isDirectory: true)
    }

    static let profileSubdirectories = [
        AppConstants.DirectoryNames.shaderpacks,
        AppConstants.DirectoryNames.resourcepacks,
        AppConstants.DirectoryNames.mods,
        AppConstants.DirectoryNames.datapacks,
        AppConstants.DirectoryNames.crashReports,
    ]

    /// 日志文件目录 - 使用系统标准日志目录，失败时回退到应用支持目录
    static var logsDirectory: URL {
        if let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            return libraryDirectory.appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent(Bundle.main.appName, isDirectory: true)
        }
        // 备用方案：使用应用支持目录下的 logs 子目录
        return launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.logs, isDirectory: true)
    }
}

extension AppPaths {
    static func resourceDirectory(for type: String, gameName: String) -> URL? {
        switch type.lowercased() {
        case ResourceType.mod.rawValue: return modsDirectory(gameName: gameName)
        case ResourceType.datapack.rawValue: return datapacksDirectory(gameName: gameName)
        case ResourceType.shader.rawValue: return shaderpacksDirectory(gameName: gameName)
        case ResourceType.resourcepack.rawValue: return resourcepacksDirectory(gameName: gameName)
        default: return nil
        }
    }

    /// 根据本地文件所在目录名推断资源类型（mod / shader / resourcepack / datapack）
    /// - Parameter fileURL: 本地资源文件路径
    /// - Returns: 资源类型字符串，或 nil 表示无法推断
    static func resourceType(for fileURL: URL) -> String? {
        let parentDirName = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()

        switch parentDirName {
        case AppConstants.DirectoryNames.mods.lowercased():
            return ResourceType.mod.rawValue
        case AppConstants.DirectoryNames.shaderpacks.lowercased():
            return ResourceType.shader.rawValue
        case AppConstants.DirectoryNames.resourcepacks.lowercased():
            return ResourceType.resourcepack.rawValue
        case AppConstants.DirectoryNames.datapacks.lowercased():
            return ResourceType.datapack.rawValue
        default:
            return nil
        }
    }
    /// 全局缓存文件路径 - 使用系统标准缓存目录，异常时回退到应用支持目录下的 Cache
    static var appCache: URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cachesDirectory.appendingPathComponent(Bundle.main.identifier)
        }
        Logger.shared.error("无法获取系统缓存目录，使用应用支持目录下的 Cache")
        return launcherSupportDirectory.appendingPathComponent("Cache", isDirectory: true)
    }

    /// 数据目录路径
    static var dataDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.data, isDirectory: true)
    }

    /// 本地皮肤库存储目录
    static var skinsDirectory: URL {
        dataDirectory.appendingPathComponent("skins", isDirectory: true)
    }

    /// 游戏版本数据库路径
    static var gameVersionDatabase: URL {
        dataDirectory.appendingPathComponent("data.db")
    }
}
