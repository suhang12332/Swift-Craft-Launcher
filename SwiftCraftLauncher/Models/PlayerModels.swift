import Foundation

/// 玩家信息模型
/// 用于存储和管理玩家的基本信息
struct Player: Identifiable, Codable, Equatable {
    /// 玩家唯一标识符
    let id: String

    /// 玩家名称
    let name: String
    /// 是否为在线账号
    var isOnlineAccount: Bool
    /// 玩家头像路径或URL
    let avatarName: String
    var authXuid: String
    var authAccessToken: String
    /// Refresh Token（用于自动刷新访问令牌）
    var authRefreshToken: String
    /// 账号创建时间
    let createdAt: Date

    /// 最后游玩时间
    var lastPlayed: Date

    /// 是否为当前选中的玩家
    var isCurrent: Bool

    /// 初始化玩家信息
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID，如果为nil则生成离线UUID
    ///   - createdAt: 创建时间，默认当前时间
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - isOnlineAccount: 是否在线账号，默认false
    ///   - isCurrent: 是否当前玩家，默认false
    /// - Throws: 如果生成玩家ID失败则抛出错误
    init(
        name: String,
        uuid: String? = nil,
        isOnlineAccount: Bool,
        avatarName: String,
        authXuid: String,
        authAccessToken: String,
        authRefreshToken: String = "",
        createdAt: Date = Date(),
        lastPlayed: Date = Date(),
        isCurrent: Bool = false
    ) throws {
        // 如果提供了UUID则使用，否则生成离线UUID
        if let providedUUID = uuid {
            self.id = providedUUID
        } else {
            self.id = try PlayerUtils.generateOfflineUUID(for: name)
        }
        self.name = name
        self.isOnlineAccount = isOnlineAccount
        self.avatarName = isOnlineAccount ? avatarName : PlayerUtils.avatarName(for: self.id) ?? "steve"
        self.createdAt = createdAt
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
        self.authAccessToken = authAccessToken
        self.authRefreshToken = authRefreshToken
        self.authXuid = authXuid
    }
}
