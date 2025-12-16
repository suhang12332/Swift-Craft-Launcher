import Foundation

enum AppPaths {
    // MARK: - Path Cache
    /// 路径缓存，避免重复创建相同的 URL 对象
    private static let pathCache = NSCache<NSString, NSURL>()
    private static let cacheQueue = DispatchQueue(label: "com.swiftcraftlauncher.apppaths.cache", attributes: .concurrent)

    // MARK: - Cached Path Helper
    /// 获取缓存的 URL 路径，如果不存在则创建并缓存
    private static func cachedURL(key: String, factory: () -> URL) -> URL {
        return cacheQueue.sync {
            if let cached = pathCache.object(forKey: key as NSString) {
                return cached as URL
            }
            let url = factory()
            pathCache.setObject(url as NSURL, forKey: key as NSString)
            return url
        }
    }

    static var launcherSupportDirectory: URL {
    // guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
    //     return nil
    // }
        return cachedURL(key: "launcherSupportDirectory") {
            .applicationSupportDirectory.appendingPathComponent(Bundle.main.appName)
        }
    }
    static var runtimeDirectory: URL {
        launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.runtime)
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
        let customPath = GeneralSettingsManager.shared.launcherWorkingDirectory
        let workingDirectory = customPath.isEmpty ? launcherSupportDirectory.path : customPath

        let baseURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        return baseURL.appendingPathComponent(AppConstants.DirectoryNames.profiles, isDirectory: true)
    }

    static func profileDirectory(gameName: String) -> URL {
        cachedURL(key: "profileDirectory:\(gameName)") {
            profileRootDirectory.appendingPathComponent(gameName)
        }
    }

    static func modsDirectory(gameName: String) -> URL {
        cachedURL(key: "modsDirectory:\(gameName)") {
            profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.mods)
        }
    }

    static func datapacksDirectory(gameName: String) -> URL {
        cachedURL(key: "datapacksDirectory:\(gameName)") {
            profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.datapacks)
        }
    }

    static func shaderpacksDirectory(gameName: String) -> URL {
        cachedURL(key: "shaderpacksDirectory:\(gameName)") {
            profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.shaderpacks)
        }
    }

    static func resourcepacksDirectory(gameName: String) -> URL {
        cachedURL(key: "resourcepacksDirectory:\(gameName)") {
            profileDirectory(gameName: gameName).appendingPathComponent(AppConstants.DirectoryNames.resourcepacks)
        }
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
            return launcherSupportDirectory.appendingPathComponent(AppConstants.DirectoryNames.cache)
        }
        return cachesDirectory.appendingPathComponent(Bundle.main.identifier)
    }
}
