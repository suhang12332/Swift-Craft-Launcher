import Foundation

/// 项目内统一管理 Notification.Name 的扩展
extension Notification.Name {
    // MARK: - 玩家相关
    static let playerUpdated = Notification.Name("PlayerUpdated")

    /// Minecraft 账号好友偏好（好友列表开关等）已在服务端更新；用于使后台 Presence 轮询重新拉取偏好。
    static let minecraftFriendsAccountPreferencesDidChange = Notification.Name("SwiftCraftLauncher.MinecraftFriendsAccountPreferencesDidChange")

    // MARK: - 游戏运行相关
    static let gameCrashed = Notification.Name("SwiftCraftLauncher.GameCrashed")

    // MARK: - 应用空闲/冻结相关
    static let appDidEnterIdleFreeze = Notification.Name("app.didEnterIdleFreeze")
    static let appDidExitIdleFreeze = Notification.Name("app.didExitIdleFreeze")

    // MARK: - 窗口管理相关
    static let openWindow = Notification.Name("OpenWindow")
}
