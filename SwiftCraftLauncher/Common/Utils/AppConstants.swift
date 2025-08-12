import Foundation

enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = ["vanilla", "fabric", "forge", "neoforge", "quilt"]
    static let defaultJava = "/usr/bin"
    
    // Minecraft 客户端ID
    static let clientId: String = {
        let encrypted = Bundle.main.object(forInfoDictionaryKey: "CLIENTID") as? String
        let obfuscator = ClientIDObfuscator(encryptedString: encrypted!)
        return obfuscator.getClientID()
    }()
    static let scope = "XboxLive.signin offline_access"
    
    // 缓存资源类型
    static let cacheResourceTypes = ["libraries", "natives", "assets", "versions"]
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
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Swift Craft Launcher"
    }
    var copyright: String {
        return infoDictionary?["Copyright"] as? String ?? "Copyright © 2025 \(appName)"
    }
}
