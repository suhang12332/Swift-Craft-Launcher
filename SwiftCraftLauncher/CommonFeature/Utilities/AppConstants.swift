//
//  AppConstants.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Defines application-wide constants and configuration values.
enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = GameLoader.allCases.map(\.rawValue)
    static let modrinthIndex = "relevance"
    static let modrinthIndexFileName = "modrinth.index.json"

    enum URLCacheConfig {
        static let memoryCapacity = 2 * 1024 * 1024
        static let diskCapacity = 10 * 1024 * 1024
    }

    enum UserDefaultsKeys {
        static let userProfiles = "userProfiles"

        static let currentPlayerId = "currentPlayerId"
        static let enableOfflineLogin = "enableOfflineLogin"
        static let enableEphemeralWebLogin = "enableEphemeralWebLogin"
        static let defaultYggdrasilServerBaseURL = "defaultYggdrasilServerBaseURL"
        static let enableHistorySkinLibrary = "enableHistorySkinLibrary"
        static let enableMinecraftFriendsPresenceNotifications = "enableMinecraftFriendsPresenceNotifications"
        static let hasAddedPremiumAccount = "hasAddedPremiumAccount"
        static let offlineUserServerMap = "offlineUserServerMap"

        static let aiProvider = "aiProvider"
        static let aiOllamaBaseURL = "aiOllamaBaseURL"
        static let aiOpenAIBaseURL = "aiOpenAIBaseURL"
        static let aiModelOverride = "aiModelOverride"
        static let aiAvatarURL = "aiAvatarURL"

        static let globalXms = "globalXms"
        static let globalXmx = "globalXmx"
        static let enableAICrashAnalysis = "enableAICrashAnalysis"
        static let defaultAPISource = "defaultAPISource"
        static let includeSnapshotsForGameVersions = "includeSnapshotsForGameVersions"
        static let syncLanguageForNewGames = "syncLanguageForNewGames"

        static let enableGitHubProxy = "enableGitHubProxy"
        static let gitProxyURL = "gitProxyURL"
        static let limitCommonSheetHeight = "limitCommonSheetHeight"
        static let concurrentDownloads = "concurrentDownloads"
        static let launcherWorkingDirectory = "launcherWorkingDirectory"
        static let interfaceLayoutStyle = "interfaceLayoutStyle"
        static let defaultModPackExportFormat = "defaultModPackExportFormat"
        static let acknowledgedAnnouncementVersion = "acknowledgedAnnouncementVersion"
        static let themeMode = "themeMode"
    }

    enum KeychainAccounts {
        static let aiSettings = "aiSettings"
    }

    enum KeychainKeys {
        static let apiKey = "apiKey"
        static let authCredential = "authCredential"
    }

    /// The Minecraft client ID, decrypted at launch.
    static let minecraftClientId: String = {
        let encrypted = "$(CLIENTID)"
        return Obfuscator.decryptClientID(encrypted)
    }()
    static let minecraftScope = "XboxLive.signin offline_access"
    static let validResourceTypes = [ResourceType.mod.rawValue, ResourceType.datapack.rawValue, ResourceType.shader.rawValue, ResourceType.resourcepack.rawValue]
    /// The CurseForge API key, decrypted at launch.
    static let curseForgeAPIKey: String? = {
        let encrypted = "$(CURSEFORGE_API_KEY)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    /// The LittleSkin OAuth client secret, decrypted at launch.
    static let littleSkinClientSecret: String? = {
        let encrypted = "$(LITTLESKIN_CLIENT_SECRET)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    /// The MUA OAuth client secret, decrypted at launch.
    static let muaClientSecret: String? = {
        let encrypted = "$(MUA_CLIENT_SECRET)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()

    /// The Ely.by OAuth client secret, decrypted at launch.
    static let elyClientSecret: String? = {
        let encrypted = "$(ELYBY_CLIENT_SECRET)"
        return Obfuscator.decryptAPIKey(encrypted)
    }()
    static let cacheResourceTypes = [DirectoryNames.libraries, DirectoryNames.natives, DirectoryNames.assets, DirectoryNames.versions]

    static let logTag = Bundle.main.identifier + ".logger"

    /// Minecraft directory name constants.
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

    /// The top-level directories and files selected by default in the file tree.
    static let defaultFileTreeTopLevelSelections: [String] = [
        DirectoryNames.config,
        DirectoryNames.datapacks,
        DirectoryNames.mods,
        DirectoryNames.resourcepacks,
        DirectoryNames.shaderpacks,
        DirectoryNames.option,
    ]

    /// File extension constants without leading dots.
    enum FileExtensions {
        static let jar = "jar"
        static let png = "png"
        static let zip = "zip"
        static let json = "json"
        static let log = "log"
        static let mrpack = "mrpack"
    }

    enum AuthlibInjector {
        static let version = "1.2.7"
        static let jarFileName = "authlib-injector-\(version).jar"
        static let agentPrefix = "-javaagent:"

        /// The full path to the authlib-injector JAR file.
        static var jarPath: String {
            AppPaths.authDirectory.appendingPathComponent(jarFileName).path
        }

        /// Returns the `-javaagent` argument string for authlib-injector.
        static func agentArgument(serverApiRoot: String) -> String {
            "\(agentPrefix)\(jarPath)=\(serverApiRoot)"
        }
    }

    /// Minecraft environment type constants.
    enum EnvironmentTypes {
        static let client = "client"
        static let server = "server"
    }

    /// Processor placeholder constants used in version manifests.
    enum ProcessorPlaceholders {
        static let side = "{SIDE}"
        static let version = "{VERSION}"
        static let versionName = "{VERSION_NAME}"
        static let libraryDir = "{LIBRARY_DIR}"
        static let workingDir = "{WORKING_DIR}"
    }

    /// Database table name constants.
    enum DatabaseTables {
        static let gameVersions = "game_versions"
        static let modCache = "mod_cache"
        static let skinLibrary = "skin_library"
    }

    /// Minecraft version constants.
    enum MinecraftVersions {
        /// The minimum Minecraft version required for certain features.
        static let featureBaseline = "1.13"
    }

    /// Mojang runtime components excluded from game settings (Legacy, Alpha, Beta).
    static let gameSettingsRuntimeExcludedComponents: Set<String> = [
        "jre-legacy",
        "java-runtime-alpha",
        "java-runtime-beta",
    ]

    enum SystemSettingsDeepLinks {
        static let localizationApps = [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension?Apps",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
        ]

        static let networkProxies = [
            "x-apple.systempreferences:com.apple.Network-Settings.extension?Proxies",
            "x-apple.systempreferences:com.apple.Network-Settings.extension",
        ]
    }
}

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
        return infoDictionary?["CFBundleName"] as? String ?? "Swift Craft Launcher"
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
