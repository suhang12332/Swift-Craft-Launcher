import Foundation

enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = GameLoader.allCases.map(\.rawValue)
    static let modrinthIndex = "relevance"
    static let modrinthIndexFileName = "modrinth.index.json"

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        // Player profiles
        static let userProfiles = "userProfiles"

        // Player settings
        static let currentPlayerId = "currentPlayerId"
        static let enableOfflineLogin = "enableOfflineLogin"
        static let defaultYggdrasilServerBaseURL = "defaultYggdrasilServerBaseURL"
        static let hasAddedPremiumAccount = "hasAddedPremiumAccount"
        static let offlineUserServerMap = "offlineUserServerMap"

        // AI settings
        static let aiProvider = "aiProvider"
        static let aiOllamaBaseURL = "aiOllamaBaseURL"
        static let aiOpenAIBaseURL = "aiOpenAIBaseURL"
        static let aiModelOverride = "aiModelOverride"
        static let aiAvatarURL = "aiAvatarURL"

        // Game settings
        static let globalXms = "globalXms"
        static let globalXmx = "globalXmx"
        static let enableAICrashAnalysis = "enableAICrashAnalysis"
        static let defaultAPISource = "defaultAPISource"
        static let includeSnapshotsForGameVersions = "includeSnapshotsForGameVersions"
        static let syncLanguageForNewGames = "syncLanguageForNewGames"

        // General settings
        static let enableGitHubProxy = "enableGitHubProxy"
        static let gitProxyURL = "gitProxyURL"
        static let limitCommonSheetHeight = "limitCommonSheetHeight"
        static let concurrentDownloads = "concurrentDownloads"
        static let launcherWorkingDirectory = "launcherWorkingDirectory"
        static let interfaceLayoutStyle = "interfaceLayoutStyle"
        static let defaultModPackExportFormat = "defaultModPackExportFormat"
        static let acknowledgedAnnouncementVersion = "acknowledgedAnnouncementVersion"

        // Theme
        static let themeMode = "themeMode"
    }

    // MARK: - System UserDefaults Keys
    /// 系统（Apple）预定义的 UserDefaults key
    enum SystemUserDefaultsKeys {
        static let appleLanguages = "AppleLanguages"
    }

    // MARK: - Keychain Keys
    enum KeychainAccounts {
        static let aiSettings = "aiSettings"
    }

    enum KeychainKeys {
        static let apiKey = "apiKey"
        static let authCredential = "authCredential"
    }

    // Minecraft 客户端ID - 构建时会被替换
    // Minecraft/Xbox认证
    static let minecraftClientId: String = {
        let encrypted = "$(CLIENTID)"
        return Obfuscator.decryptClientID(encrypted)
    }()
    static let minecraftScope = "XboxLive.signin offline_access"
    static let callbackURLScheme = "swift-craft-launcher"
    static let validResourceTypes = [ResourceType.mod.rawValue, ResourceType.datapack.rawValue, ResourceType.shader.rawValue, ResourceType.resourcepack.rawValue]
    // CurseForge API Key - 构建时会被替换
    static let curseForgeAPIKey: String? = {
        let encrypted = "$(CURSEFORGE_API_KEY)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    // LittleSkin OAuth Client Secret - 构建时注入
    static let littleSkinClientSecret: String? = {
        let encrypted = "$(LITTLESKIN_CLIENT_SECRET)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    // MUA OAuth Client Secret - 构建时注入
    static let muaClientSecret: String? = {
        let encrypted = "$(MUA_CLIENT_SECRET)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    // Ely.by OAuth Client Secret - 构建时注入
    static let elyClientSecret: String? = {
        let encrypted = "$(ELYBY_CLIENT_SECRET)"
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
        static let saves = "saves"
        static let screenshots = "screenshots"
        static let schematics = "schematics"
        static let crashReports = "crash-reports"
        static let logs = "logs"
        static let profiles = "profiles"
        static let runtime = "runtime"
        static let meta = "meta"
        static let cache = "cache"
        static let data = "data"
        static let auth = "auth"
        static let config = "config"
        static let option = "options.txt"
    }

    // MARK: - Default Selections
    /// 文件树默认预选中的顶级目录/文件名
    static let defaultFileTreeTopLevelSelections: [String] = [
        DirectoryNames.config,
        DirectoryNames.datapacks,
        DirectoryNames.mods,
        DirectoryNames.resourcepacks,
        DirectoryNames.shaderpacks,
        DirectoryNames.option,
    ]

    // MARK: - File Extensions
    /// 文件扩展名常量（不包含点号）
    enum FileExtensions {
        static let jar = "jar"
        static let png = "png"
        static let zip = "zip"
        static let json = "json"
        static let log = "log"
    }

    // MARK: - Authlib Injector
    enum AuthlibInjector {
        static let version = "1.2.7"
        static let jarFileName = "authlib-injector-\(version).jar"
        static let agentPrefix = "-javaagent:"

        /// authlib-injector.jar 的完整路径
        static var jarPath: String {
            AppPaths.authDirectory.appendingPathComponent(jarFileName).path
        }

        /// 构建 authlib-injector 的 -javaagent 参数（使用内部 jarPath）
        /// 形如：-javaagent:/path/to/jar=SERVER_API_ROOT
        static func agentArgument(serverApiRoot: String) -> String {
            "\(agentPrefix)\(jarPath)=\(serverApiRoot)"
        }
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

    // MARK: - Database Tables
    /// 数据库表名常量
    enum DatabaseTables {
        static let gameVersions = "game_versions"
        static let modCache = "mod_cache"
    }

    // MARK: - Minecraft Versions
    /// Minecraft 版本相关常量
    enum MinecraftVersions {
        /// 启用部分特性的最低 Minecraft 版本
        static let featureBaseline = "1.13"
    }

    // MARK: - Java Runtime
    /// 游戏设置里不展示的 Mojang 运行时（Legacy / Alpha / Beta）
    static let gameSettingsRuntimeExcludedComponents: Set<String> = [
        "jre-legacy",
        "java-runtime-alpha",
        "java-runtime-beta",
    ]
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
