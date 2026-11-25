//
//  YggdrasilAuthService+TokenChain.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Performs Yggdrasil OAuth2 token exchange and profile retrieval.
extension YggdrasilAuthService {
    func exchangeCodeForToken(code: String, server: YggdrasilServerConfig) async throws -> TokenResponse {
        var additionalParams: [String: String] = [:]
        if let clientSecret = server.clientSecret {
            additionalParams["client_secret"] = clientSecret
        }

        return try await OAuth2TokenOperations.exchangeCode(
            code: code,
            tokenURL: server.tokenURL,
            clientId: server.clientId ?? "",
            redirectURI: server.redirectURI,
            scope: server.scope.isEmpty ? nil : server.scope,
            additionalParameters: additionalParams,
        )
    }

    private func refreshToken(refreshToken: String, server: YggdrasilServerConfig) async throws -> TokenResponse {
        AppLog.common.debug("Refreshing token for server \(server.name)")

        var additionalParams: [String: String] = [:]
        if let clientSecret = server.clientSecret {
            additionalParams["client_secret"] = clientSecret
        }

        let result = try await OAuth2TokenOperations.refreshToken(
            refreshToken: refreshToken,
            tokenURL: server.tokenURL,
            clientId: server.clientId ?? "",
            additionalParameters: additionalParams,
        )
        AppLog.common.info("Token refreshed successfully for server \(server.name)")
        return result
    }

    /// Fetches profile data from the server's profile endpoint.
    ///
    /// When `idToken` is provided, its `selectedProfile` is used as the seed
    /// and the profile UUID is appended to `profilePath` for an individual lookup.
    func fetchProfileList(
        accessToken: String,
        server: YggdrasilServerConfig,
        idToken: String? = nil,
    ) async throws -> [YggdrasilProfileCandidate] {
        if server.parserId == .mua {
            guard let idToken, !idToken.isEmpty else {
                throw GlobalError.validation(
                    i18nKey: "yggdrasil.error.id_token_missing",
                    level: .notification,
                )
            }

            let seed = try profileFromIDToken(idToken)
            return [try await enrichProfile(
                seed,
                accessToken: accessToken,
                server: server,
            )]
        }

        let data = try await fetchProfileData(
            accessToken: accessToken,
            server: server,
            profileId: nil,
        )
        return try await parseProfileList(data: data, server: server)
    }

    private func enrichProfile(
        _ seed: YggdrasilProfileCandidate,
        accessToken: String,
        server: YggdrasilServerConfig,
    ) async throws -> YggdrasilProfileCandidate {
        let data = try await fetchProfileData(
            accessToken: accessToken,
            server: server,
            profileId: seed.id,
        )
        let candidates = try await parseProfileList(data: data, server: server)
        guard let first = candidates.first else {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_profile_parse_failed",
                level: .notification,
                message: "No profile returned for \(seed.name) (\(seed.id))",
            )
        }

        return YggdrasilProfileCandidate(
            id: seed.id,
            name: first.name.isEmpty ? seed.name : first.name,
            skins: first.skins,
            capes: first.capes,
        )
    }

    private func profileFromIDToken(_ idToken: String) throws -> YggdrasilProfileCandidate {
        guard let payload = JWTDecoder.decodePayload(from: idToken),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let claims = try? JSONDecoder().decode(YggdrasilIDTokenClaims.self, from: data) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.error.id_token_invalid",
                level: .notification,
            )
        }

        guard let selectedProfile = claims.selectedProfile else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.error.id_token_missing_selected_profile",
                level: .notification,
            )
        }

        let id = selectedProfile.id
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        guard !id.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.error.id_token_missing_selected_profile",
                level: .notification,
            )
        }

        return YggdrasilProfileCandidate(id: id, name: selectedProfile.name)
    }

    private func fetchProfileData(
        accessToken: String,
        server: YggdrasilServerConfig,
        profileId: String?,
    ) async throws -> Data {
        let headers = [APIClient.Header.authorization: APIClient.bearer(accessToken)]
        return try await APIClient.get(
            url: server.profileURL(for: profileId),
            headers: headers,
        )
    }

    private func parseProfileList(
        data: Data,
        server: YggdrasilServerConfig,
    ) async throws -> [YggdrasilProfileCandidate] {
        guard let parser = YggdrasilProfileParsers.make(server.parserId) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_profile_parse_failed",
                level: .notification,
                message: "No profile parser available for parserId=\(server.parserId), server=\(server.baseURL.absoluteString)",
            )
        }

        if let candidates = await parser.parse(data: data) {
            return candidates
        }

        throw GlobalError.validation(
            i18nKey: "error.validation.yggdrasil_profile_parse_failed",
            level: .notification,
            message: "Profile parser returned nil for parserId=\(server.parserId), server=\(server.baseURL.absoluteString), data size=\(data.count)",
        )
    }

    func refreshThirdPartyToken(profile: YggdrasilProfile, server: YggdrasilServerConfig) async {
        var updatedProfile = profile
        do {
            let tokenResponse = try await refreshToken(
                refreshToken: profile.refreshToken,
                server: server,
            )
            updatedProfile = YggdrasilProfile(
                id: profile.id,
                name: profile.name,
                skins: profile.skins,
                capes: profile.capes,
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? profile.refreshToken,
                serverBaseURL: profile.serverBaseURL,
            )
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }

        OfflineUserServerMap.setServer(updatedProfile)
    }

    func getMinecraftToken(profile: YggdrasilProfile, server: YggdrasilServerConfig) async throws -> String {
        guard let parser = YggdrasilMinecraftTokenParsers.make(for: server.parserId) else {
            AppLog.common.error("Minecraft token fetch not yet implemented for this server (\(server.name)), falling back to OAuth2 token")
            return profile.accessToken
        }

        return try await parser.fetchMinecraftToken(
            profileId: profile.id,
            minecraftTokenURL: server.minecraftTokenURL,
            oauthToken: profile.accessToken,
        )
    }
}

private struct YggdrasilIDTokenProfile: Decodable {
    let id: String
    let name: String
}

private struct YggdrasilIDTokenClaims: Decodable {
    let selectedProfile: YggdrasilIDTokenProfile?
}
