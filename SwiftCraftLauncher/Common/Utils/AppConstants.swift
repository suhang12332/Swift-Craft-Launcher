import Foundation

enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = ["vanilla", "fabric", "forge", "neoforge", "quilt"]
    static let modrinthIndex = "relevance"

    // Minecraft 客户端ID - 构建时会被替换
    // Minecraft/Xbox认证
    static let minecraftClientId: String = {
        let encrypted = "$(CLIENTID)"
        return Obfuscator.decryptClientID(encrypted)
    }()
    static let minecraftScope = "XboxLive.signin offline_access"
    static let callbackURLScheme = "swift-craft-launcher"

    // CurseForge API Key - 构建时会被替换
    static let curseForgeAPIKey: String? = {
        let encrypted = "$(CURSEFORGE_API_KEY)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()
    // 缓存资源类型
    static let cacheResourceTypes = [DirectoryNames.libraries, DirectoryNames.natives, DirectoryNames.assets, DirectoryNames.versions]

    static let logTag = Bundle.main.identifier + ".logger"

    // MARK: - Directory Names
    /// Minecraft 目录名称常量
    enum DirectoryNames {
        static let mods = "mods"
        static let libraries = "libraries"
        static let natives = "natives"
        static let assets = "assets"
        static let versions = "versions"
        static let shaderpacks = "shaderpacks"
        static let resourcepacks = "resourcepacks"
        static let datapacks = "datapacks"
        static let schematics = "schematics"
        static let crashReports = "crash-reports"
        static let logs = "logs"
        static let profiles = "profiles"
        static let runtime = "runtime"
        static let meta = "meta"
        static let cache = "cache"
    }

    // MARK: - File Extensions
    /// 文件扩展名常量（不包含点号）
    enum FileExtensions {
        static let jar = "jar"
        static let png = "png"
        static let zip = "zip"
        static let json = "json"
        static let log = "log"
    }

    // MARK: - Environment Types
    /// 环境类型常量
    enum EnvironmentTypes {
        static let client = "client"
        static let server = "server"
    }

    // MARK: - Processor Placeholders
    /// Processor 占位符常量
    enum ProcessorPlaceholders {
        static let side = "{SIDE}"
        static let version = "{VERSION}"
        static let versionName = "{VERSION_NAME}"
        static let libraryDir = "{LIBRARY_DIR}"
        static let workingDir = "{WORKING_DIR}"
    }

    // MARK: - UserDefaults Keys
    /// UserDefaults 存储键常量
    enum UserDefaultsKeys {
        static let savedGames = "savedGames"
    }
}

// MARK: - Bundle Extension
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "beta"
    }

    var fullVersion: String {
        return "\(appVersion)-\(buildNumber)"
    }
    var appName: String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Swift Craft Launcher"
    }
    var copyright: String {
        return infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright © 2025 \(appName)"
    }

    var identifier: String {
        return infoDictionary?["CFBundleIdentifier"] as? String ?? "com.su.code.SwiftCraftLauncher"
    }

    var appCategory: String {
        return infoDictionary?["LSApplicationCategoryType"] as? String ?? "public.app-category.games"
    }
}
