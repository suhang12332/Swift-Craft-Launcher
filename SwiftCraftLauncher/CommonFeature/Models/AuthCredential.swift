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

    /// Xbox 用户ID（XUID）
    var xuid: String

    /// 初始化认证凭据
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - accessToken: 访问令牌
    ///   - refreshToken: 刷新令牌
    ///   - xuid: Xbox 用户ID，默认为空字符串
    init(
        userId: String,
        accessToken: String,
        refreshToken: String,
        xuid: String = ""
    ) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.xuid = xuid
    }
}
