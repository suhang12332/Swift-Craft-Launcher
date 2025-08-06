import Foundation

enum AppConstants {
    static let defaultGameIcon = "default_game_icon.png"
    static let modLoaders = ["vanilla", "fabric", "forge", "neoforge", "quilt"]
    static let defaultJava = "/usr/bin"
    
    // Minecraft 客户端ID - 支持从环境变量读取
    static let clientId: String = {
        // 优先从环境变量读取（用于CI/CD）
        if let envClientId = ProcessInfo.processInfo.environment["MINECRAFT_CLIENT_ID"] {
            return envClientId
        }
        // 如果环境变量不存在，使用默认值
        return "***"
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
}
