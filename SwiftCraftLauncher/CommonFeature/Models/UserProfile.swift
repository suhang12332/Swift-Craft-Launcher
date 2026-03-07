import Foundation

/// 用户基本信息模型
/// 存储在 plist 文件中
struct UserProfile: Identifiable, Codable, Equatable {
    /// 用户唯一标识符
    let id: String

    /// 用户名称
    let name: String

    /// 头像名称或路径
    let avatar: String

    /// 最后游玩时间
    var lastPlayed: Date

    /// 是否为当前选中的用户
    var isCurrent: Bool

    /// 账户提供方
    let provider: AccountProvider

    /// 初始化用户基本信息
    /// - Parameters:
    ///   - id: 用户唯一标识符
    ///   - name: 用户名称
    ///   - avatar: 头像名称或路径
    ///   - lastPlayed: 最后游玩时间，默认当前时间
    ///   - isCurrent: 是否为当前选中的用户，默认 false
    init(
        id: String,
        name: String,
        avatar: String,
        lastPlayed: Date = Date(),
        isCurrent: Bool = false,
        provider: AccountProvider = .offline
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
        self.provider = provider
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatar
        case lastPlayed
        case isCurrent
        case provider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatar = try container.decode(String.self, forKey: .avatar)
        lastPlayed = try container.decode(Date.self, forKey: .lastPlayed)
        isCurrent = try container.decode(Bool.self, forKey: .isCurrent)
        provider = try container.decodeIfPresent(AccountProvider.self, forKey: .provider)
            ?? AccountProvider.inferFromLegacyAvatar(avatar)
    }
}
