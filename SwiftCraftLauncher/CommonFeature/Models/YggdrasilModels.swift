import Foundation

/// Yggdrasil profile 列表解析器标识
enum YggdrasilProfileParserID: String, Codable, CaseIterable, Identifiable {
    case littleskin
    case mua
    case ely

    var id: String { rawValue }
}

struct YggdrasilServerConfig: Codable, Equatable, Hashable {
    /// 服务器在 UI 中展示用的名称（可选）
    var name: String?
    var baseURL: String
    var clientId: String?
    var clientSecret: String?
    var redirectURI: String
    var authorizePath: String
    var tokenPath: String
    var profilePath: String
    var scope: String
    var parserId: YggdrasilProfileParserID

    init(
        name: String? = nil,
        baseURL: String,
        clientId: String? = nil,
        clientSecret: String? = nil,
        redirectURI: String,
        authorizePath: String,
        tokenPath: String,
        profilePath: String,
        scope: String,
        parserId: YggdrasilProfileParserID
    ) {
        self.name = name
        self.baseURL = Self.normalizeBaseURL(baseURL)
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.authorizePath = Self.normalizePath(authorizePath)
        self.tokenPath = Self.normalizePath(tokenPath)
        self.profilePath = Self.normalizePath(profilePath)
        self.scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        self.parserId = parserId
    }

    private static func normalizeBaseURL(_ baseURL: String) -> String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func normalizePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "/" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    /// 授权端点：{baseURL}{authorizePath}
    var authorizeURL: URL? {
        URL(string: baseURL)?.appendingPathComponent(authorizePath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    /// 令牌端点：{baseURL}{tokenPath}
    var tokenURL: URL? {
        URL(string: baseURL)?.appendingPathComponent(tokenPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    /// 玩家资料端点：{baseURL}{profilePath}
    var profileURL: URL? {
        URL(string: baseURL)?
            .appendingPathComponent(profilePath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    // /// 可选：传统 refresh 接口（/authserver/refresh）
    // var refreshURL: URL? {
    //     URL(string: baseURL)?
    //         .appendingPathComponent("authserver/refresh")
    // }
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

struct YggdrasilProfileCandidate: Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?
}

enum YggdrasilAuthState: Equatable {
    case idle
    case waitingForBrowser
    case exchangingCode
    case authenticated(profile: YggdrasilProfile)
    case failed(String)
}
