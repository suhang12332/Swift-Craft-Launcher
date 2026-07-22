//
//  OAuth2TokenOperations.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared OAuth2 token exchange and refresh operations.
enum OAuth2TokenOperations {
    /// Exchanges an authorization code for tokens.
    static func exchangeCode(
        code: String,
        tokenURL: URL,
        clientId: String,
        redirectURI: String,
        scope: String?,
        additionalParameters: [String: String] = [:],
    ) async throws -> TokenResponse {
        var parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
        ]
        if let scope {
            parameters["scope"] = scope
        }
        parameters.merge(additionalParameters) { _, new in new }

        let data = try await APIClient.post(
            url: tokenURL,
            body: APIClient.formURLEncodedBody(from: parameters),
            headers: APIClient.DefaultHeaders.contentTypeFormURLEncoded,
        )

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.token_response_parse_failed",
                level: .notification,
                message: "Failed to parse token response from \(tokenURL): \(error.localizedDescription)",
            )
        }
    }

    /// Refreshes an existing token.
    static func refreshToken(
        refreshToken: String,
        tokenURL: URL,
        clientId: String,
        additionalParameters: [String: String] = [:],
    ) async throws -> TokenResponse {
        var parameters: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ]
        parameters.merge(additionalParameters) { _, new in new }

        let (data, statusCode) = try await APIClient.postUnchecked(
            url: tokenURL,
            body: APIClient.formURLEncodedBody(from: parameters),
            headers: APIClient.DefaultHeaders.contentTypeFormURLEncodedUTF8,
        )

        guard statusCode == 200 else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? String {
                switch error {
                case "invalid_grant":
                    throw GlobalError.authentication(
                        i18nKey: "error.authentication.invalid_refresh_token",
                        level: .popup,
                        message: "Refresh token rejected as invalid_grant for client \(clientId)",
                    )
                default:
                    throw GlobalError.authentication(
                        i18nKey: "error.authentication.refresh_token_error",
                        level: .popup,
                        message: "Refresh token error '\(error)' (HTTP \(statusCode)) for client \(clientId)",
                    )
                }
            }
            throw GlobalError.authentication(
                i18nKey: "error.authentication.refresh_token_request_failed",
                level: .notification,
                message: "Refresh token request failed with HTTP \(statusCode) for client \(clientId)",
            )
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.token_response_parse_failed",
                level: .notification,
                message: "Failed to parse refresh token response from \(tokenURL): \(error.localizedDescription)",
            )
        }
    }
}
