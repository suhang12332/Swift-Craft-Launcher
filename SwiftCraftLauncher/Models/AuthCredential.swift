import Foundation

/// 认证凭据模型
/// 存储在 Keychain 中
struct AuthCredential: Codable, Equatable {
    /// 用户ID（与 UserProfile.id 对应）
    let userId: String

    /// 访问令牌
    var accessToken: String

    /// 刷新令牌
    var refreshToken: String

    /// 令牌过期时间
    var expiresAt: Date?

    /// Xbox 用户ID（XUID）
    var xuid: String
    
    /// Yggdrasil 服务器基础URL（仅用于 Yggdrasil 认证）
    var yggdrasilServerURL: String?

    /// 初始化认证凭据
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - accessToken: 访问令牌
    ///   - refreshToken: 刷新令牌
    ///   - expiresAt: 令牌过期时间，可选
    ///   - xuid: Xbox 用户ID，默认为空字符串
    ///   - yggdrasilServerURL: Yggdrasil 服务器基础URL，可选
    init(
        userId: String,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date? = nil,
        xuid: String = "",
        yggdrasilServerURL: String? = nil
    ) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.xuid = xuid
        self.yggdrasilServerURL = yggdrasilServerURL
    }
}
