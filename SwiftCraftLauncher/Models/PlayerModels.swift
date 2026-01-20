import Foundation

/// 玩家信息模型
/// 组合 UserProfile 和可选的 AuthCredential
/// 不直接存储，而是从 UserProfileStore 和 AuthCredentialStore 加载
struct Player: Identifiable, Equatable {
    /// 用户基本信息
    var profile: UserProfile

    /// 认证凭据（仅在线账号有）
    var credential: AuthCredential?

    // MARK: - Computed Properties

    /// 玩家唯一标识符
    var id: String { profile.id }

    /// 玩家名称
    var name: String { profile.name }

    /// 玩家头像路径或URL
    var avatarName: String { profile.avatar }

    /// 最后游玩时间
    var lastPlayed: Date {
        get { profile.lastPlayed }
        set { profile.lastPlayed = newValue }
    }

    /// 是否为当前选中的玩家
    var isCurrent: Bool {
        get { profile.isCurrent }
        set { profile.isCurrent = newValue }
    }

    /// 是否为在线账号
    /// 优先依据认证凭据；在尚未从 Keychain 加载凭据时，
    /// 通过头像是否为远程 URL（http/https）来近似判断是否为正版账号
    var isOnlineAccount: Bool {
        if credential != nil {
            return true
        }
        return profile.avatar.hasPrefix("http://") || profile.avatar.hasPrefix("https://")
    }

    /// 访问令牌
    var authAccessToken: String { credential?.accessToken ?? "" }

    /// 刷新令牌
    var authRefreshToken: String { credential?.refreshToken ?? "" }

    /// Xbox 用户ID
    var authXuid: String { credential?.xuid ?? "" }

    /// 令牌过期时间
    var expiresAt: Date? { credential?.expiresAt }

    /// 初始化玩家信息
    /// - Parameters:
    ///   - profile: 用户基本信息
    ///   - credential: 认证凭据（可选，离线账号为 nil）
    init(profile: UserProfile, credential: AuthCredential? = nil) {
        self.profile = profile
        self.credential = credential
    }

    /// 初始化玩家信息（便捷方法）
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID，如果为nil则生成离线UUID
    ///   - avatar: 头像名称或路径
    ///   - credential: 认证凭据（可选）
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - isCurrent: 是否当前玩家，默认false
    /// - Throws: 如果生成玩家ID失败则抛出错误
    init(
        name: String,
        uuid: String? = nil,
        avatar: String? = nil,
        credential: AuthCredential? = nil,
        lastPlayed: Date = Date(),
        isCurrent: Bool = false
    ) throws {
        // 如果提供了UUID则使用，否则生成离线UUID
        let playerId: String
        if let providedUUID = uuid {
            playerId = providedUUID
        } else {
            playerId = try PlayerUtils.generateOfflineUUID(for: name)
        }

        // 确定头像
        let avatarName: String
        if let providedAvatar = avatar {
            avatarName = providedAvatar
        } else if credential != nil {
            // 在线账号需要提供头像
            avatarName = ""
        } else {
            // 离线账号使用默认头像
            avatarName = PlayerUtils.avatarName(for: playerId) ?? "steve"
        }

        let profile = UserProfile(
            id: playerId,
            name: name,
            avatar: avatarName,
            lastPlayed: lastPlayed,
            isCurrent: isCurrent
        )

        self.profile = profile
        self.credential = credential
    }
}
