//
//  MicrosoftAuthDTOs.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

struct AuthorizationCodeResponse {
    let code: String?
    let error: String?
    let errorDescription: String?

    var isSuccess: Bool {
        code != nil && error == nil
    }

    var isUserDenied: Bool {
        error == "access_denied"
    }

    init?(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        code = queryItems.first { $0.name == "code" }?.value
        error = queryItems.first { $0.name == "error" }?.value
        if let encodedDescription = queryItems.first(where: { $0.name == "error_description" })?.value {
            errorDescription = encodedDescription.removingPercentEncoding
        } else {
            errorDescription = nil
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }

    init(accessToken: String, refreshToken: String? = nil, idToken: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
    }
}

struct XboxLiveTokenResponse: Codable {
    let token: String
    let displayClaims: DisplayClaims

    enum CodingKeys: String, CodingKey {
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }
}

struct DisplayClaims: Codable {
    let xui: [XUI]
}

struct XUI: Codable {
    let uhs: String
}

struct MinecraftEntitlementsResponse: Codable {
    let items: [EntitlementItem]
    let signature: String
    let keyId: String
}

struct EntitlementItem: Codable {
    let name: String
    let signature: String
}
