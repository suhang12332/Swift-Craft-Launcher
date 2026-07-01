//
//  MinecraftAuthService+TokenChain.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Performs the Microsoft OAuth token exchange chain to obtain Minecraft access tokens.
extension MinecraftAuthService {
    func exchangeCodeForToken(code: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token

        let bodyParameters = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "scope": scope,
        ]

        let data = try await APIClient.post(
            url: url,
            body: APIClient.formURLEncodedBody(from: bodyParameters),
            headers: APIClient.DefaultHeaders.contentTypeFormURLEncoded,
        )

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.token_response_parse_failed",
                level: .notification,
            )
        }
    }

    func getXboxLiveTokenThrowing(accessToken: String) async throws -> XboxLiveTokenResponse {
        let url = URLConfig.API.Authentication.xboxLiveAuth

        let body: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": URLConfig.API.Authentication.xboxLiveSiteName,
                "RpsTicket": "d=\(accessToken)",
            ],
            "RelyingParty": URLConfig.API.Authentication.xboxLiveRelyingParty,
            "TokenType": "JWT",
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.xbox_live_request_serialize_failed",
                level: .notification,
            )
        }

        let headers = APIClient.DefaultHeaders.contentTypeJSON
        let data = try await APIClient.post(url: url, body: bodyData, headers: headers)

        do {
            return try JSONDecoder().decode(XboxLiveTokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.xbox_live_token_parse_failed",
                level: .notification,
            )
        }
    }

    func getMinecraftTokenThrowing(xboxToken: String, uhs: String) async throws -> String {
        let xstsUrl = URLConfig.API.Authentication.xstsAuth

        let xstsBody: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xboxToken],
            ],
            "RelyingParty": URLConfig.API.Authentication.minecraftRelyingParty,
            "TokenType": "JWT",
        ]

        let xstsBodyData: Data
        do {
            xstsBodyData = try JSONSerialization.data(withJSONObject: xstsBody)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.xsts_request_serialize_failed",
                level: .notification,
            )
        }

        let xstsHeaders = APIClient.DefaultHeaders.contentTypeJSON
        let xstsData = try await APIClient.post(url: xstsUrl, body: xstsBodyData, headers: xstsHeaders)

        let xstsTokenResponse: XboxLiveTokenResponse
        do {
            xstsTokenResponse = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: xstsData)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.xsts_token_parse_failed",
                level: .notification,
            )
        }

        AppLog.common.debug("Starting to fetch Minecraft access token")
        let minecraftUrl = URLConfig.API.Authentication.minecraftLogin

        let minecraftBody: [String: Any] = [
            "identityToken": "XBL3.0 x=\(uhs);\(xstsTokenResponse.token)",
        ]

        let minecraftBodyData: Data
        do {
            minecraftBodyData = try JSONSerialization.data(withJSONObject: minecraftBody)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.minecraft_request_serialize_failed",
                level: .notification,
            )
        }

        let minecraftData: Data
        do {
            minecraftData = try await APIClient.post(
                url: minecraftUrl,
                body: minecraftBodyData,
                headers: APIClient.DefaultHeaders.contentTypeJSON,
            )
        } catch let error as GlobalError where error.kind == .network {
            switch error.statusCode {
            case 401:
                throw GlobalError.authentication(
                    i18nKey: "error.authentication.invalid_xbox_token",
                    level: .notification,
                )
            case 403:
                throw GlobalError.authentication(
                    i18nKey: "error.authentication.minecraft_not_owned",
                    level: .notification,
                )
            case 429:
                throw GlobalError.network(
                    i18nKey: "error.network.rate_limited",
                )
            case 503:
                throw GlobalError.network(
                    i18nKey: "error.network.minecraft_service_unavailable",
                )
            default:
                throw error
            }
        }

        let minecraftTokenResponse: TokenResponse
        do {
            minecraftTokenResponse = try JSONDecoder().decode(TokenResponse.self, from: minecraftData)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.minecraft_token_parse_failed",
                level: .notification,
            )
        }

        return minecraftTokenResponse.accessToken
    }

    func checkMinecraftOwnership(accessToken: String) async throws {
        let url = URLConfig.API.Authentication.minecraftEntitlements
        let headers = [
            APIClient.Header.authorization: APIClient.bearer(accessToken),
            APIClient.Header.accept: APIClient.MimeType.json,
        ]
        let data: Data
        do {
            data = try await APIClient.get(url: url, headers: headers)
        } catch let error as GlobalError where error.kind == .network {
            switch error.statusCode {
            case 401:
                throw GlobalError.authentication(
                    i18nKey: "error.authentication.invalid_minecraft_token",
                    level: .notification,
                )
            case 403:
                throw GlobalError.authentication(
                    i18nKey: "error.authentication.minecraft_not_purchased",
                    level: .popup,
                )
            default:
                throw error
            }
        }

        do {
            let entitlements = try JSONDecoder().decode(MinecraftEntitlementsResponse.self, from: data)

            let hasProductMinecraft = entitlements.items.contains {
                $0.name == MinecraftEntitlement.productMinecraft.rawValue
            }
            let hasGameMinecraft = entitlements.items.contains {
                $0.name == MinecraftEntitlement.gameMinecraft.rawValue
            }

            if !hasProductMinecraft || !hasGameMinecraft {
                throw GlobalError.authentication(
                    i18nKey: "error.authentication.insufficient_minecraft_entitlements",
                    level: .popup,
                )
            }
        } catch let decodingError as DecodingError {
            throw GlobalError.validation(
                i18nKey: "error.validation.entitlements_parse_failed",
                level: .notification,
            )
        } catch let globalError as GlobalError {
            throw globalError
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.entitlements_check_unknown_error",
                level: .notification,
            )
        }
    }

    func getMinecraftProfileThrowing(
        accessToken: String,
        authXuid: String,
        refreshToken: String = "",
    ) async throws -> MinecraftProfileResponse {
        let url = URLConfig.API.Authentication.minecraftProfile
        let headers = [APIClient.Header.authorization: APIClient.bearer(accessToken)]
        let data = try await APIClient.get(url: url, headers: headers)

        do {
            let profile = try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)

            return MinecraftProfileResponse(
                id: profile.id,
                name: profile.name,
                skins: profile.skins,
                capes: profile.capes,
                accessToken: accessToken,
                authXuid: authXuid,
                refreshToken: refreshToken,
            )
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.minecraft_profile_parse_failed",
                level: .notification,
            )
        }
    }
}
