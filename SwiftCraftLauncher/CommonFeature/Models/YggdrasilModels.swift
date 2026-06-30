//
//  YggdrasilModels.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Identifies a Yggdrasil profile parser implementation.
enum YggdrasilProfileParserID: String, Codable, CaseIterable, Identifiable {
    case littleskin
    case mua
    case ely

    var id: String { rawValue }
}

struct YggdrasilServerConfig: Codable, Equatable, Hashable {
    /// The display name for this server in the UI.
    var name: String
    var baseURL: URL
    var clientId: String?
    var clientSecret: String?
    var redirectURI: String
    var authorizePath: String
    var tokenPath: String
    var profilePath: String
    var scope: String
    var parserId: YggdrasilProfileParserID
    var token: String

    init(
        name: String,
        baseURL: URL,
        clientId: String? = nil,
        clientSecret: String? = nil,
        redirectURI: String,
        authorizePath: String,
        tokenPath: String,
        profilePath: String,
        scope: String,
        parserId: YggdrasilProfileParserID,
        token: String,
    ) {
        self.name = name
        self.baseURL = baseURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.authorizePath = authorizePath
        self.tokenPath = tokenPath
        self.profilePath = profilePath
        self.scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        self.parserId = parserId
        self.token = token
    }

    /// The full authorize URL derived from the base URL and authorize path.
    var authorizeURL: URL? {
        baseURL.appendingPathComponent(authorizePath)
    }

    /// The full token URL derived from the base URL and token path.
    var tokenURL: URL? {
        baseURL.appendingPathComponent(tokenPath)
    }

    /// The full profile URL derived from the base URL and profile path.
    var profileURL: URL? {
        baseURL.appendingPathComponent(profilePath)
    }

    var minecraftTokenURL: URL {
        baseURL.appendingPathComponent(token)
    }
}

struct YggdrasilProfile: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?

    let accessToken: String
    let refreshToken: String
    let serverBaseURL: String
}

struct YggdrasilProfileCandidate: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?

    init(id: String, name: String, skins: [Skin] = [], capes: [Cape]? = nil) {
        self.id = id
        self.name = name
        self.skins = skins
        self.capes = capes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        skins = (try? container.decode([Skin].self, forKey: .skins)) ?? []
        capes = try? container.decode([Cape].self, forKey: .capes)
    }
}

/// The current state of the Yggdrasil authentication flow.
enum YggdrasilAuthState: Equatable {
    case idle
    case waitingForBrowser
    case exchangingCode
    case authenticated(profile: YggdrasilProfile)
    case failed(String)
}
