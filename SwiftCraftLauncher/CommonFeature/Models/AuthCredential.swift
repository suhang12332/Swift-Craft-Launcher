import Foundation

/// 认证凭据模型
/// 存储在 Keychain 中
struct AuthCredential: Codable, Equatable {
    /// 用户ID（与 UserProfile.id 对应）
    let userId: String

    /// 账户提供方
    var provider: AccountProvider

    /// 访问令牌
    var accessToken: String

    /// Yggdrasil Client Token
    var clientToken: String

    /// 刷新令牌
    var refreshToken: String

    /// 令牌过期时间
    var expiresAt: Date?

    /// Xbox 用户ID（XUID）
    var xuid: String

    /// 初始化认证凭据
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - accessToken: 访问令牌
    ///   - refreshToken: 刷新令牌
    ///   - expiresAt: 令牌过期时间，可选
    ///   - xuid: Xbox 用户ID，默认为空字符串
    init(
        userId: String,
        provider: AccountProvider = .microsoft,
        accessToken: String,
        clientToken: String = "",
        refreshToken: String,
        expiresAt: Date? = nil,
        xuid: String = "",
        authServerBaseURL: String = ""
    ) {
        self.userId = userId
        self.provider = provider
        self.accessToken = accessToken
        self.clientToken = clientToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.xuid = xuid
        self.authServerBaseURL = authServerBaseURL.isEmpty
            ? provider.defaultAuthServerBaseURL
            : authServerBaseURL
    }

    /// 认证服务器基础地址
    var authServerBaseURL: String

    enum CodingKeys: String, CodingKey {
        case userId
        case provider
        case accessToken
        case clientToken
        case refreshToken
        case expiresAt
        case xuid
        case authServerBaseURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        provider = try container.decodeIfPresent(AccountProvider.self, forKey: .provider) ?? .microsoft
        accessToken = try container.decode(String.self, forKey: .accessToken)
        clientToken = try container.decodeIfPresent(String.self, forKey: .clientToken) ?? ""
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        xuid = try container.decodeIfPresent(String.self, forKey: .xuid) ?? ""
        authServerBaseURL = try container.decodeIfPresent(String.self, forKey: .authServerBaseURL)
            ?? provider.defaultAuthServerBaseURL
    }
}
