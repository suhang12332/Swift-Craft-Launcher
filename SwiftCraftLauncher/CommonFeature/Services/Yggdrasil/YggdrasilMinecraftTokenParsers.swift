//
//  YggdrasilMinecraftTokenParsers.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Defines a parser for fetching Minecraft access tokens from Yggdrasil-compatible servers.
protocol YggdrasilMinecraftTokenParser {
    /// Fetches a Minecraft access token from the authentication server.
    func fetchMinecraftToken(profileId: String, minecraftTokenURL: URL, oauthToken: String) async throws -> String
}

/// Registry for Minecraft token parsers by server type.
enum YggdrasilMinecraftTokenParsers {
    static func make(for parserId: YggdrasilProfileParserID) -> YggdrasilMinecraftTokenParser? {
        switch parserId {
        case .littleskin:
            return LittleSkinMinecraftTokenParser()
        case .mua, .ely:
            return nil
        }
    }
}

/// Fetches Minecraft access tokens from LittleSkin authentication servers.
struct LittleSkinMinecraftTokenParser: YggdrasilMinecraftTokenParser {
    struct Response: Codable {
        let accessToken: String
    }

    func fetchMinecraftToken(profileId: String, minecraftTokenURL: URL, oauthToken: String) async throws -> String {
        // LittleSkin needs a short delay after the OAuth token is issued or
        // refreshed before the token can be used to create a Minecraft token.
        // Requesting too early makes this endpoint fail.
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let bodyData = try JSONSerialization.data(withJSONObject: ["uuid": profileId])
        let data = try await APIClient.post(
            url: minecraftTokenURL,
            body: bodyData,
            headers: [
                APIClient.Header.authorization: APIClient.bearer(oauthToken),
                APIClient.Header.contentType: APIClient.MimeType.json,
            ],
        )
        return try JSONDecoder().decode(Response.self, from: data).accessToken
    }
}
