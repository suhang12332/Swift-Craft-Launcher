//
//  MinecraftAuth.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

struct AuthorizationCodeResponse {
    let code: String?
    let error: String?
    let errorDescription: String?

    var isSuccess: Bool {
        return code != nil && error == nil
    }

    var isUserDenied: Bool {
        return error == "access_denied"
    }

    init?(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        self.code = queryItems.first { $0.name == "code" }?.value
        self.error = queryItems.first { $0.name == "error" }?.value
        if let encodedDescription = queryItems.first(where: { $0.name == "error_description" })?.value {
            self.errorDescription = encodedDescription.removingPercentEncoding
        } else {
            self.errorDescription = nil
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
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

    enum CodingKeys: String, CodingKey {
        case xui = "xui"
    }
}

struct XUI: Codable {
    let uhs: String

    enum CodingKeys: String, CodingKey {
        case uhs
    }
}

struct MinecraftProfileResponse: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?
    let accessToken: String
    let authXuid: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case skins
        case capes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        skins = try container.decode([Skin].self, forKey: .skins)
        capes = try container.decodeIfPresent([Cape].self, forKey: .capes)
        accessToken = ""
        authXuid = ""
        refreshToken = ""
    }

    init(id: String, name: String, skins: [Skin], capes: [Cape]?, accessToken: String, authXuid: String, refreshToken: String = "") {
        self.id = id
        self.name = name
        self.skins = skins
        self.capes = capes
        self.accessToken = accessToken
        self.authXuid = authXuid
        self.refreshToken = refreshToken
    }
}

struct Skin: Codable, Equatable {
    let state: String
    let url: String
    let variant: String?
}

struct Cape: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let alias: String?
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

enum MinecraftEntitlement: String, CaseIterable {
    case productMinecraft = "product_minecraft"
    case gameMinecraft = "game_minecraft"

    var displayName: String {
        switch self {
        case .productMinecraft:
            return "Minecraft Product License"
        case .gameMinecraft:
            return "Minecraft Game License"
        }
    }
}

/// The current state of the Microsoft authentication flow.
enum AuthenticationState: Equatable {
    case notAuthenticated
    case waitingForBrowserAuth
    case processingAuthCode
    case authenticated(profile: MinecraftProfileResponse)
    case error(String)
}
