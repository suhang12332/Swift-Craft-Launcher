import Foundation

/// Minecraft 令牌获取协议：不同三方站请求和响应格式各异，各自实现
protocol YggdrasilMinecraftTokenParser {
    /// 通过三方站获取 Minecraft access token
    func fetchMinecraftToken(profileId: String, minecraftTokenURL: URL, oauthToken: String) async throws -> String
}

/// Minecraft 令牌解析器注册表
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

// MARK: - LittleSkin

/// LittleSkin: POST {baseURL}/api/yggdrasil/authserver/oauth
/// Headers: Authorization: Bearer {oauthToken}
/// Body: { "uuid": "{profileId}" }
/// Response: { "accessToken": "..." }
struct LittleSkinMinecraftTokenParser: YggdrasilMinecraftTokenParser {
    struct Response: Codable {
        let accessToken: String
    }

    func fetchMinecraftToken(profileId: String, minecraftTokenURL: URL, oauthToken: String) async throws -> String {
        let bodyData = try JSONSerialization.data(withJSONObject: ["uuid": profileId])
        let data = try await APIClient.post(
            url: minecraftTokenURL,
            body: bodyData,
            headers: [
                "Authorization": "Bearer \(oauthToken)",
                APIClient.Header.contentType: APIClient.MimeType.json,
            ]
        )
        return try JSONDecoder().decode(Response.self, from: data).accessToken
    }
}
