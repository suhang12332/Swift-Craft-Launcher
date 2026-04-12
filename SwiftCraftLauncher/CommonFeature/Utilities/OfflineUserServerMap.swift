import Foundation

/// 离线玩家对应的第三方认证/皮肤服务器映射
/// 不修改 `UserProfile` 结构，通过 UserDefaults 维护 [userId: serverKey] 映射
enum OfflineUserServerMap {
    /// 加载完整映射
    private static func loadMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap) as? [String: String] ?? [:]
    }

    /// 为指定用户设置服务器标识
    static func setServer(_ serverKey: String, for userId: String) {
        var map = loadMap()
        map[userId] = serverKey
        UserDefaults.standard.set(map, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
    }

    /// 删除指定用户对应的服务器标识
    /// - Parameter userId: 玩家 ID
    static func removeServer(for userId: String) {
        var map = loadMap()
        map.removeValue(forKey: userId)
        UserDefaults.standard.set(map, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
    }

    /// 读取指定用户对应的服务器标识
    /// - Parameter userId: 玩家 ID
    /// - Returns: 服务器标识，如果不存在则返回 nil
    static func serverKey(for userId: String) -> String? {
        loadMap()[userId]
    }
}
