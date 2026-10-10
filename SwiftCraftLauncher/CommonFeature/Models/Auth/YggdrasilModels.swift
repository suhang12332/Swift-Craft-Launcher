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
    /// Custom password-login server: profiles come straight from the authenticate response.
    case custom

    var id: String { rawValue }
}

/// How users sign in to a Yggdrasil server.
enum YggdrasilLoginMethod: String, Codable {
    /// OAuth2 authorization code flow (built-in presets).
    case oauth
    /// Classic authserver username/password flow (custom skin sites).
    case password
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
    /// The login method; defaults to OAuth (built-in presets).
    var loginMethod: YggdrasilLoginMethod
    /// The authlib-injector API root of a password server (authserver endpoints derive from it).
    var apiRoot: URL?

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
        loginMethod: YggdrasilLoginMethod = .oauth,
        apiRoot: URL? = nil,
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
        self.loginMethod = loginMethod
        self.apiRoot = apiRoot
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

    /// The authserver API root for password login; `nil` for OAuth servers.
    var passwordAPIRoot: URL? {
        guard loginMethod == .password else { return nil }
        return apiRoot ?? baseURL
    }

    /// Whether the server uses username/password login.
    var isPasswordLogin: Bool { loginMethod == .password }
}

struct YggdrasilProfile: Codable, Equatable {
    let id: String
    var name: String
    var skins: [Skin]
    let capes: [Cape]?

    var accessToken: String
    let refreshToken: String
    let serverBaseURL: String

    /// The login method. `nil` means OAuth, which keeps profiles stored before
    /// password login existed decodable.
    var loginMethod: YggdrasilLoginMethod?
    /// The classic protocol clientToken (password login only).
    var clientToken: String?
    /// The login name used for password login (needed for automatic re-login).
    var loginUsername: String?
    /// The password, kept only when the user opts in to remember it.
    var savedPassword: String?

    init(
        id: String,
        name: String,
        skins: [Skin],
        capes: [Cape]?,
        accessToken: String,
        refreshToken: String,
        serverBaseURL: String,
        loginMethod: YggdrasilLoginMethod? = nil,
        clientToken: String? = nil,
        loginUsername: String? = nil,
        savedPassword: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.skins = skins
        self.capes = capes
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.serverBaseURL = serverBaseURL
        self.loginMethod = loginMethod
        self.clientToken = clientToken
        self.loginUsername = loginUsername
        self.savedPassword = savedPassword
    }

    /// Whether this profile was signed in with username/password.
    var isPasswordLogin: Bool { loginMethod == .password }

    /// Returns a copy with the given skin URL prepended (used to show the avatar after
    /// password login). Empty or already-present URLs leave the profile unchanged.
    func withSkinURL(_ url: String?) -> Self {
        guard let url, !url.isEmpty, !skins.contains(where: { $0.url == url }) else {
            return self
        }
        var updated = self
        updated.skins.insert(Skin(state: "ACTIVE", url: url, variant: nil), at: 0)
        return updated
    }
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
typealias YggdrasilAuthState = AuthFlowState<YggdrasilProfile>
