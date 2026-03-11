import Foundation

/// LittleSkin 等具体皮肤站相关的服务器分类
enum LittleSkinServerKind: String {
    case littleskin
    case generic

    static func kind(for baseURL: String) -> Self {
        let lower = baseURL.lowercased()
        if lower.contains("littleskin") {
            return .littleskin
        }
        return .generic
    }
}

/// LittleSkin 专用的 Yggdrasil 服务器预设
enum LittleSkinServerPresets {
    static let servers: [YggdrasilServerConfig] = [
        YggdrasilServerConfig(
            name: "LittleSkin",
            baseURL: "https://littleskin.cn",
            clientId: "1181",
            clientSecret: AppConstants.littleSkinClientSecret,
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/yggdrasil/sessionserver/session/minecraft/profile",
            scope: "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read",
            parserId: .littleskin
        ),
    ]
}
