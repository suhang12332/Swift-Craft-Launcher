//
//  YggdrasilServerPresets.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
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
            clientId: "34",
            clientSecret: AppConstants.muaClientSecret,
            // redirectURI: URLConfig.API.Authentication.redirectUri,
            redirectURI: "swift-craft-launcher://auth",
            authorizePath: "/oauth/authorize",
            tokenPath: "/oauth/token",
            profilePath: "/api/players",
            scope: "Player.Read User.Read",
            parserId: .mua,
            token: "/api/yggdrasil/authserver/oauth",
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
