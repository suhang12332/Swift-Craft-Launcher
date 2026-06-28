import Foundation

/// 离线玩家对应的第三方认证/皮肤服务器映射
/// 不修改 `UserProfile` 结构，通过 UserDefaults 维护 [userId: YggdrasilProfile] 映射
enum OfflineUserServerMap {
    /// 加载完整映射
    private static func loadMap() -> [String: YggdrasilProfile] {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap),
              let map = try? JSONDecoder().decode([String: YggdrasilProfile].self, from: data) else {
            return [:]
        }
        return map
    }

    /// 为指定用户设置 Yggdrasil 配置
    static func setServer(_ profile: YggdrasilProfile, for userId: String) {
        var map = loadMap()
        map[userId] = profile
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
        }
    }

    /// 删除指定用户对应的 Yggdrasil 配置
    /// - Parameter userId: 玩家 ID
    static func removeServer(for userId: String) {
        var map = loadMap()
        map.removeValue(forKey: userId)
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
        }
    }

    /// 读取指定用户对应的 Yggdrasil 配置
    /// - Parameter userId: 玩家 ID
    /// - Returns: Yggdrasil 配置，如果不存在则返回 nil
    static func serverKey(for userId: String) -> YggdrasilProfile? {
        loadMap()[userId]
    }

    /// 判断指定用户是否绑定了 Yggdrasil 配置
    static func contains(userId: String) -> Bool {
        loadMap()[userId] != nil
    }
}
