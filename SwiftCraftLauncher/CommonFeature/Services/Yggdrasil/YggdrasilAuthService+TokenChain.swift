//
//  YggdrasilAuthService+TokenChain.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Performs Yggdrasil OAuth2 token exchange and profile retrieval.
extension YggdrasilAuthService {
    func exchangeCodeForToken(code: String, server: YggdrasilServerConfig) async throws -> TokenResponse {
        guard let tokenURL = server.tokenURL else {
            throw GlobalError.validation(
                chineseMessage: "Token 地址无效",
                i18nKey: "error.validation.yggdrasil_token_url_invalid",
                level: .notification,
            )
        }

        var parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": server.redirectURI,
        ]

        if let clientId = server.clientId {
            parameters["client_id"] = clientId
        }
        if let clientSecret = server.clientSecret {
            parameters["client_secret"] = clientSecret
        }

        let data = try await APIClient.post(
            url: tokenURL,
            body: APIClient.formURLEncodedBody(from: parameters),
            headers: APIClient.DefaultHeaders.contentTypeFormURLEncoded,
        )

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Yggdrasil Token 响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.yggdrasil_token_response_parse_failed",
                level: .notification,
            )
        }
    }

    func fetchProfileList(
        accessToken: String,
        server: YggdrasilServerConfig,
    ) async throws -> [YggdrasilProfileCandidate] {
        guard let profileURL = server.profileURL else {
            throw GlobalError.validation(
                chineseMessage: "玩家资料地址无效",
                i18nKey: "error.validation.yggdrasil_profile_url_invalid",
                level: .notification,
            )
        }

        let headers = [APIClient.Header.authorization: APIClient.bearer(accessToken)]
        let data = try await APIClient.get(url: profileURL, headers: headers)

        guard let parser = YggdrasilProfileParsers.make(server.parserId, baseURL: server.baseURL.absoluteString) else {
            throw GlobalError.validation(
                chineseMessage: "未找到对应的 Yggdrasil 玩家资料解析器",
                i18nKey: "error.validation.yggdrasil_profile_parse_failed",
                level: .notification,
            )
        }

        if let candidates = await parser.parse(data: data) {
            return candidates
        }

        throw GlobalError.validation(
            chineseMessage: "解析 Yggdrasil 玩家资料失败：格式无法识别",
            i18nKey: "error.validation.yggdrasil_profile_parse_failed",
            level: .notification,
        )
    }

    func getMinecraftToken(profile: YggdrasilProfile, server: YggdrasilServerConfig) async throws -> String {
        guard let parser = YggdrasilMinecraftTokenParsers.make(for: server.parserId) else {
            AppLog.common.error("TODO: 该服务器（\(server.name)）暂未实现 Minecraft 令牌获取，回退使用 OAuth2 token")
            return profile.accessToken
        }
        return try await parser.fetchMinecraftToken(
            profileId: profile.id,
            minecraftTokenURL: server.minecraftTokenURL,
            oauthToken: profile.accessToken,
        )
    }
}
