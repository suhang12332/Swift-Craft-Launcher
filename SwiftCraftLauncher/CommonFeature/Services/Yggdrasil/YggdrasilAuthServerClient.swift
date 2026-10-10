//
//  YggdrasilAuthServerClient.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A player profile embedded in Yggdrasil classic authenticate/refresh responses.
struct YggdrasilAuthProfile: Codable, Equatable {
    let id: String
    let name: String
}

/// Response body of `POST /authserver/authenticate` and `POST /authserver/refresh`.
struct YggdrasilAuthenticateResponse: Codable, Equatable {
    let accessToken: String
    let clientToken: String
    let availableProfiles: [YggdrasilAuthProfile]?
    let selectedProfile: YggdrasilAuthProfile?
}

/// Fine-grained rejection reasons returned by a classic authserver.
///
/// The protocol reports both wrong passwords and invalid tokens as HTTP 403 with
/// `ForbiddenOperationException`; they are told apart by `errorMessage` so that the
/// renewal state machine can choose the right branch.
enum YggdrasilAuthServerError: Error {
    /// Wrong username or password (or temporarily blocked); retrying is pointless.
    case invalidCredentials
    /// The token is invalid; refresh or re-login is required.
    case invalidToken
    /// Any other rejection, carrying the server-provided message.
    case rejected(String)
}

/// A sessionserver profile, used to display the avatar.
struct YggdrasilSessionProfile: Codable, Equatable {
    let id: String
    let name: String
    /// The skin texture URL, or `nil` when the profile has no skin.
    let skinURL: String?
}

/// Abstraction over the Yggdrasil classic authserver API (a seam for unit tests).
protocol YggdrasilAuthServerClientProtocol: Sendable {
    /// Signs in with a username and password.
    func authenticate(
        username: String,
        password: String,
        clientToken: String,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse

    /// Refreshes the token; binds the given profile when `selectedProfileId` is non-nil.
    func refresh(
        accessToken: String,
        clientToken: String,
        selectedProfileId: String?,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse

    /// Validates the token (HTTP 204 means valid).
    func validate(accessToken: String, clientToken: String, apiRoot: URL) async -> Bool

    /// Fetches the profile (including the skin URL) to show the avatar after password login.
    func fetchSessionProfile(uuid: String, apiRoot: URL) async throws -> YggdrasilSessionProfile
}

/// Default implementation backed by the shared `APIClient`.
struct YggdrasilAuthServerClient: YggdrasilAuthServerClientProtocol {
    private static let invalidTokenMarker = "invalid token"
    private static let invalidCredentialsMarker = "invalid credentials"

    func authenticate(
        username: String,
        password: String,
        clientToken: String,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        let body: [String: Any] = [
            "agent": ["name": "Minecraft", "version": 1],
            "username": username,
            "password": password,
            "clientToken": clientToken,
            "requestUser": false,
        ]
        return try await post(body: body, url: endpoint(apiRoot, action: "authenticate"))
    }

    func refresh(
        accessToken: String,
        clientToken: String,
        selectedProfileId: String?,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        var body: [String: Any] = [
            "accessToken": accessToken,
            "clientToken": clientToken,
        ]
        if let selectedProfileId {
            body["selectedProfile"] = ["id": selectedProfileId]
        }
        return try await post(body: body, url: endpoint(apiRoot, action: "refresh"))
    }

    func validate(accessToken: String, clientToken: String, apiRoot: URL) async -> Bool {
        let body: [String: Any] = [
            "accessToken": accessToken,
            "clientToken": clientToken,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        do {
            let (_, statusCode) = try await APIClient.postUnchecked(
                url: endpoint(apiRoot, action: "validate"),
                body: data,
                headers: APIClient.DefaultHeaders.contentTypeJSON,
            )
            // Per the spec, a valid token yields 204 No Content.
            return statusCode == 204
        } catch {
            return false
        }
    }

    func fetchSessionProfile(uuid: String, apiRoot: URL) async throws -> YggdrasilSessionProfile {
        let url = apiRoot.appendingPathComponent("sessionserver/session/minecraft/profile/\(uuid)")
        let data = try await APIClient.get(url: url, headers: [:])

        struct RawProfile: Codable {
            struct Property: Codable {
                let name: String
                let value: String
            }

            let id: String
            let name: String
            let properties: [Property]
        }

        let raw = try JSONDecoder().decode(RawProfile.self, from: data)
        let textureValue = raw.properties.first { $0.name == "textures" }?.value
        return YggdrasilSessionProfile(id: raw.id, name: raw.name, skinURL: textureValue.flatMap(Self.skinURL(fromTextureValue:)))
    }

    /// Decodes the SKIN texture URL from the base64(url)-encoded `textures` property.
    static func skinURL(fromTextureValue base64: String) -> String? {
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while !padded.count.isMultiple(of: 4) {
            padded += "="
        }
        guard let data = Data(base64Encoded: padded),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let textures = object["textures"] as? [String: Any],
              let skin = textures["SKIN"] as? [String: Any] else {
            return nil
        }
        return skin["url"] as? String
    }

    private func endpoint(_ apiRoot: URL, action: String) -> URL {
        apiRoot.appendingPathComponent("authserver/\(action)")
    }

    private func post(body: [String: Any], url: URL) async throws -> YggdrasilAuthenticateResponse {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_request_serialize_failed",
                level: .notification,
                message: "Failed to serialize Yggdrasil authserver request for \(url): \(error.localizedDescription)",
            )
        }

        let (responseData, statusCode) = try await APIClient.postUnchecked(
            url: url,
            body: data,
            headers: APIClient.DefaultHeaders.contentTypeJSON,
        )
        try rejectIfDenied(data: responseData, statusCode: statusCode, url: url)

        do {
            return try JSONDecoder().decode(YggdrasilAuthenticateResponse.self, from: responseData)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_token_response_parse_failed",
                level: .notification,
                message: "Failed to parse Yggdrasil authserver response from \(url): \(error.localizedDescription)",
            )
        }
    }

    /// Maps non-2xx responses to typed errors using the protocol error body (`error` / `errorMessage`).
    private func rejectIfDenied(data: Data, statusCode: Int, url _: URL) throws {
        guard !(200 ..< 300).contains(statusCode) else { return }

        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { $0["errorMessage"] as? String } ?? ""
        let lowercased = message.lowercased()

        if statusCode == 403 {
            if lowercased.contains(Self.invalidCredentialsMarker) {
                throw YggdrasilAuthServerError.invalidCredentials
            }
            if lowercased.contains(Self.invalidTokenMarker) {
                throw YggdrasilAuthServerError.invalidToken
            }
        }
        throw YggdrasilAuthServerError.rejected(message.isEmpty ? "HTTP \(statusCode)" : message)
    }
}

/// Installation-wide Yggdrasil classic clientToken.
///
/// The spec requires a client to keep the same clientToken across requests; it is
/// generated on first use and persisted in UserDefaults (it is not a secret).
enum YggdrasilClientTokenProvider {
    static func currentToken() -> String {
        let key = AppConstants.UserDefaultsKeys.yggdrasilClientToken
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: key)
        return token
    }
}
