import Foundation

// MARK: - Device Code Response
struct DeviceCodeResponse: Codable {
    let userCode: String
    let deviceCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case deviceCode = "device_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
        case message
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
struct MinecraftProfileResponse: Codable {
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

struct Skin: Codable {
    let id: String
    let state: String
    let url: String
    let variant: String?
    let alias: String?
}

struct Cape: Codable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}

// MARK: - Authentication State
enum AuthenticationState {
    case notAuthenticated
    case requestingCode
    case waitingForUser(userCode: String, verificationUri: String)
    case authenticating
    case authenticated(profile: MinecraftProfileResponse)
    case authenticatedYggdrasil(profile: YggdrasilProfileResponse)
    case error(String)
}

// MARK: - Authentication Error
enum MinecraftAuthError: Error, LocalizedError {
    case invalidDeviceCode
    case authorizationPending
    case authorizationDeclined
    case expiredToken
    case slowDown
    case networkError(Error)
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidDeviceCode:
            return "无效的设备代码"
        case .authorizationPending:
            return "授权待处理，请完成浏览器验证"
        case .authorizationDeclined:
            return "用户拒绝了授权"
        case .expiredToken:
            return "令牌已过期"
        case .slowDown:
            return "请求过于频繁，请稍后再试"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应数据"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        }
    }
}
