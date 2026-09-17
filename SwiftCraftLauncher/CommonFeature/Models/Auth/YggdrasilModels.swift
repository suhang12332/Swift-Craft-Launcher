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
    /// 自定义密码登录服务器:角色列表直接来自 authenticate 响应,无需专用解析器。
    case custom

    var id: String { rawValue }
}

/// Yggdrasil 服务器的登录方式。
enum YggdrasilLoginMethod: String, Codable {
    /// OAuth2 授权码流程(内置三个预设)。
    case oauth
    /// classic authserver 用户名密码流程(自定义皮肤站)。
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
    /// 登录方式;默认 OAuth(内置预设)。
    var loginMethod: YggdrasilLoginMethod
    /// 密码型服务器的 authlib-injector API 根地址(authserver 端点由它派生)。
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

    /// 密码登录的 authserver API 根;密码型服务器必须提供。
    var passwordAPIRoot: URL? {
        guard loginMethod == .password else { return nil }
        return apiRoot ?? baseURL
    }

    /// 是否使用用户名密码登录。
    var isPasswordLogin: Bool { loginMethod == .password }
}

struct YggdrasilProfile: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?

    var accessToken: String
    let refreshToken: String
    let serverBaseURL: String

    /// 认证方式(OAuth 登录为 .yggdrasilOAuth,密码登录为 .yggdrasilPassword)。
    var authMethod: AccountAuthMethod
    /// classic 协议 clientToken(密码登录使用)。
    var clientToken: String?
    /// 密码登录的登录名(自动重登时使用)。
    var loginUsername: String?
    /// 登录时暂存的密码,仅当用户勾选记住时非 nil;落库后由统一凭据存储接管。
    var savedPassword: String?

    init(
        id: String,
        name: String,
        skins: [Skin],
        capes: [Cape]?,
        accessToken: String,
        refreshToken: String,
        serverBaseURL: String,
        authMethod: AccountAuthMethod = .yggdrasilOAuth,
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
        self.authMethod = authMethod
        self.clientToken = clientToken
        self.loginUsername = loginUsername
        self.savedPassword = savedPassword
    }

    /// 返回补拉了皮肤贴图的新档案(用于密码登录后的头像展示;无效地址保持原样)。
    func withSkinURL(_ url: String?) -> Self {
        guard let url, !url.isEmpty else { return self }
        if skins.contains(where: { $0.url == url }) { return self }
        var updatedSkins = skins
        updatedSkins.insert(Skin(state: "ACTIVE", url: url, variant: nil), at: 0)
        return Self(
            id: id,
            name: name,
            skins: updatedSkins,
            capes: capes,
            accessToken: accessToken,
            refreshToken: refreshToken,
            serverBaseURL: serverBaseURL,
            authMethod: authMethod,
            clientToken: clientToken,
            loginUsername: loginUsername,
            savedPassword: savedPassword,
        )
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
