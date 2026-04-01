import Foundation

/// Yggdrasil 服务器预设（LittleSkin / MUA）
enum YggdrasilServerPresets {
    static let servers: [YggdrasilServerConfig] = [
        YggdrasilServerConfig(
            name: "LittleSkin",
            baseURL: URLConfig.API.Yggdrasil.littleSkinBaseURL,
            clientId: "1181",
            clientSecret: AppConstants.littleSkinClientSecret,
            redirectURI: URLConfig.API.Authentication.redirectUri,
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/yggdrasil/sessionserver/session/minecraft/profile",
            scope: "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read",
            parserId: .littleskin
        ),
        YggdrasilServerConfig(
            name: "MUA",
            baseURL: URLConfig.API.Yggdrasil.muaBaseURL,
            clientId: "34",
            clientSecret: AppConstants.muaClientSecret,
            redirectURI: URLConfig.API.Authentication.redirectUri,
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/players",
            scope: "Player.Read User.Read",
            parserId: .mua
        ),
        YggdrasilServerConfig(
            name: "Ely.By",
            baseURL: URLConfig.API.Yggdrasil.elyBaseURL,
            clientId: "swift-craft-launcher",
            clientSecret: AppConstants.elyClientSecret,
            redirectURI: URLConfig.API.Authentication.redirectUri,
            authorizePath: "/oauth2/v1",
            tokenPath: "/api/oauth2/v1/token",
            profilePath: "/api/account/v1/info",
            scope: "account_info",
            parserId: .ely
        ),
    ]
}
