import Foundation

/// Yggdrasil 服务器预设（LittleSkin / MUA）
enum YggdrasilServerPresets {
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
        YggdrasilServerConfig(
            name: "MUA",
            baseURL: "https://skin.mualliance.ltd",
            clientId: "34",
            clientSecret: AppConstants.muaClientSecret,
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/players",
            scope: "Player.Read User.Read",
            parserId: .mua
        ),
    ]
}
