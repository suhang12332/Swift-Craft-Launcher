import Foundation

// MARK: - Yggdrasil Profile Response
struct YggdrasilProfileResponse: Codable, Equatable {
    let id: String
    let name: String
    let skins: [YggdrasilSkin]
    let capes: [YggdrasilCape]?
    let accessToken: String
    let refreshToken: String
    let serverBaseURL: String  // 自定义服务器基础URL
    
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
        skins = try container.decodeIfPresent([YggdrasilSkin].self, forKey: .skins) ?? []
        capes = try container.decodeIfPresent([YggdrasilCape].self, forKey: .capes)
        // 这些字段将在外部设置
        accessToken = ""
        refreshToken = ""
        serverBaseURL = ""
    }
    
    init(id: String, name: String, skins: [YggdrasilSkin], capes: [YggdrasilCape]?, accessToken: String, refreshToken: String, serverBaseURL: String) {
        self.id = id
        self.name = name
        self.skins = skins
        self.capes = capes
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.serverBaseURL = serverBaseURL
    }
}

struct YggdrasilSkin: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let variant: String?
    let alias: String?
}

struct YggdrasilCape: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}

// MARK: - Yggdrasil Token Response
struct YggdrasilTokenResponse: Codable {
    let accessToken: String
    let clientToken: String?
    let selectedProfile: YggdrasilSelectedProfile?
    let availableProfiles: [YggdrasilSelectedProfile]?
    let refreshToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case clientToken = "clientToken"
        case selectedProfile = "selectedProfile"
        case availableProfiles = "availableProfiles"
        case refreshToken = "refreshToken"
    }
}

struct YggdrasilSelectedProfile: Codable {
    let id: String
    let name: String
}

// MARK: - Yggdrasil Profile Response (from /sessionserver/session/minecraft/profile endpoint)
struct YggdrasilSessionProfileResponse: Codable {
    let id: String
    let name: String
    let properties: [YggdrasilProperty]
}

struct YggdrasilProperty: Codable {
    let name: String
    let value: String
    let signature: String?
}

// MARK: - Yggdrasil Authentication State
enum YggdrasilAuthenticationState: Equatable {
    case notAuthenticated
    case waitingForBrowserAuth          // 等待用户在浏览器中完成授权
    case processingAuthCode             // 处理授权码
    case authenticated(profile: YggdrasilProfileResponse)
    case error(String)
}

// MARK: - Yggdrasil Server Configuration
struct YggdrasilServerConfig: Codable, Equatable, Hashable {
    var baseURL: String
    let clientId: String?
    let clientSecret: String?
    let redirectURI: String
    
    init(baseURL: String, clientId: String? = nil, clientSecret: String? = nil, redirectURI: String = "swift-craft-launcher://yggdrasil-auth") {
        // 确保 baseURL 不以斜杠结尾
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            trimmed = String(trimmed.dropLast())
        }
        self.baseURL = trimmed
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(baseURL)
        hasher.combine(clientId)
        hasher.combine(redirectURI)
        // 注意：clientSecret 不参与 hash，因为它是敏感信息
    }
    
    /// 获取授权端点URL
    var authorizeURL: URL? {
        guard let url = URL(string: baseURL) else { return nil }
        return url.appendingPathComponent("oauth/authorize")
    }
    
    /// 获取令牌端点URL
    var tokenURL: URL? {
        guard let url = URL(string: baseURL) else { return nil }
        return url.appendingPathComponent("oauth/token")
    }
    
    /// 获取用户信息端点URL
    var profileURL: URL? {
        guard let url = URL(string: baseURL) else { return nil }
        return url.appendingPathComponent("api/yggdrasil/sessionserver/session/minecraft/profile")
    }
    
    /// 获取会话验证端点URL
    var sessionURL: URL? {
        guard let url = URL(string: baseURL) else { return nil }
        return url.appendingPathComponent("sessionserver/session/minecraft/profile")
    }
    
    /// 获取刷新令牌端点URL
    var refreshURL: URL? {
        guard let url = URL(string: baseURL) else { return nil }
        return url.appendingPathComponent("authserver/refresh")
    }
}

