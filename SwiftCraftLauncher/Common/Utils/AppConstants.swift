import Foundation

enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = ["vanilla", "fabric", "forge", "neoforge", "quilt"]
    static let defaultJava = "/usr/bin"

    // Minecraft 客户端ID - 构建时会被替换
    // Minecraft/Xbox认证
    static let minecraftClientId: String = {
        let encrypted = "$(CLIENTID)"
        let obfuscator = ClientIDObfuscator(encryptedString: encrypted)
        return obfuscator.getClientID()
    }()
    static let minecraftScope = "XboxLive.signin offline_access"

    // Yggdrasil/LittleSkin认证
    static let yggdrasilClientId = "1182" // 替换为你的实际LittleSkin客户端ID
    static let yggdrasilScope = "openid Yggdrasil.PlayerProfiles.Select" // 按需调整

    // 缓存资源类型
    static let cacheResourceTypes = ["libraries", "natives", "assets", "versions"]

    static let logTag = Bundle.main.identifier+".logger"
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
