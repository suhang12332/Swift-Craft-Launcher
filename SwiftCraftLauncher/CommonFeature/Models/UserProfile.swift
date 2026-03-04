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
        isCurrent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
    }
}
