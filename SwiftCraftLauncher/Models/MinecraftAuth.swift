import Foundation

// MARK: - Authorization Code Flow Response
struct AuthorizationCodeResponse {
    let code: String?
    let state: String?
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
        self.state = queryItems.first { $0.name == "state" }?.value
        self.error = queryItems.first { $0.name == "error" }?.value
        // 解码 error_description
        if let encodedDescription = queryItems.first(where: { $0.name == "error_description" })?.value {
            self.errorDescription = encodedDescription.removingPercentEncoding
        } else {
            self.errorDescription = nil
        }
    }
}

// MARK: - Token Response
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

// MARK: - Xbox Live Token Response
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

// MARK: - Minecraft Profile Response
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
        // accessToken 和 authXuid 不参与解码，因为它们不是从 API 响应中获取的
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        skins = try container.decode([Skin].self, forKey: .skins)
        capes = try container.decodeIfPresent([Cape].self, forKey: .capes)
        // 这些字段将在外部设置
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
    let id: String
    let state: String
    let url: String
    let variant: String?
    let alias: String?
}

struct Cape: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}

// MARK: - Minecraft Entitlements Response
struct MinecraftEntitlementsResponse: Codable {
    let items: [EntitlementItem]
    let signature: String
    let keyId: String
}

struct EntitlementItem: Codable {
    let name: String
    let signature: String
}

// MARK: - Entitlement Names
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

// MARK: - Authentication State
enum AuthenticationState: Equatable {
    case notAuthenticated
    case waitingForBrowserAuth          // 等待用户在浏览器中完成授权
    case processingAuthCode             // 处理授权码
    case authenticated(profile: MinecraftProfileResponse)
    case error(String)
}
