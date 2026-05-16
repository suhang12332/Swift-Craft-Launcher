import Foundation
import SwiftUI

class PlayerSettingsManager: ObservableObject {
    static let shared = PlayerSettingsManager()

    @AppStorage(AppConstants.UserDefaultsKeys.currentPlayerId)
    var currentPlayerId: String = "" {
        didSet { objectWillChange.send() }
    }

    /// 是否允许在启动器中使用离线登录
    @AppStorage(AppConstants.UserDefaultsKeys.enableOfflineLogin)
    var enableOfflineLogin: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// 离线登录默认使用的 Yggdrasil 皮肤站 baseURL（空表示不预设）
    @AppStorage(AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL)
    var defaultYggdrasilServerBaseURL: String = "" {
        didSet { objectWillChange.send() }
    }

    /// 是否启用历史皮肤库（仅正版账号生效）
    @AppStorage(AppConstants.UserDefaultsKeys.enableHistorySkinLibrary)
    var enableHistorySkinLibrary: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// 是否启用好友上线 / 下线 / 邀请等系统通知（需选中微软正版账号时才会后台轮询）
    @AppStorage(AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications)
    var enableMinecraftFriendsPresenceNotifications: Bool = false {
        didSet { objectWillChange.send() }
    }

    private init() {}
}
