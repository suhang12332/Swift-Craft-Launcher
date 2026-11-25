//
//  YggdrasilServerPresets.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Predefined Yggdrasil server configurations.
enum YggdrasilServerPresets {
    static let servers: [YggdrasilServerConfig] = [
        YggdrasilServerConfig(
            name: "LittleSkin",
            baseURL: URLConfig.API.Yggdrasil.littleSkinBaseURL,
            clientId: "1181",
            clientSecret: AppConstants.littleSkinClientSecret,
            // redirectURI: URLConfig.API.Authentication.redirectUri,
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/yggdrasil/sessionserver/session/minecraft/profile",
            scope: "Yggdrasil.MinecraftToken.Create Yggdrasil.PlayerProfiles.Read",
            parserId: .littleskin,
            token: "/api/yggdrasil/authserver/oauth",
        ),
        YggdrasilServerConfig(
            name: "Mua",
            baseURL: URLConfig.API.Yggdrasil.muaBaseURL,
            clientId: "37",
            clientSecret: AppConstants.muaClientSecret,
            redirectURI: URLConfig.API.Authentication.redirectUri,
            authorizePath: "/open/auth",
            tokenPath: "/open/token",
            profilePath: "/api/yggdrasil/sessionserver/session/minecraft/profile",
            scope: "openid profile Yggdrasil.PlayerProfiles.Select Yggdrasil.Server.Join offline_access",
            parserId: .mua,
            token: "/open/token",
        ),
        YggdrasilServerConfig(
            name: "Ely.By",
            baseURL: URLConfig.API.Yggdrasil.elyBaseURL,
            clientId: "swift-craft-launcher",
            clientSecret: AppConstants.elyClientSecret,
            // redirectURI: URLConfig.API.Authentication.redirectUri,
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "/oauth2/v1",
            tokenPath: "/api/oauth2/v1/token",
            profilePath: "/api/account/v1/info",
            scope: "account_info offline_access minecraft_server_session",
            parserId: .ely,
            token: "/api/yggdrasil/authserver/oauth",
        ),
    ]

    static func server(for baseURLString: String) -> YggdrasilServerConfig? {
        servers.first { $0.baseURL.absoluteString == baseURLString }
    }
}
