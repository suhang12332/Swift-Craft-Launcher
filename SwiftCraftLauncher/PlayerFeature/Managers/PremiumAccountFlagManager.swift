import Foundation

/// 正版账户标记管理器
/// 标记是否曾添加正版账户，判断是否允许添加离线账户
@MainActor
class PremiumAccountFlagManager {
    static let shared = PremiumAccountFlagManager()

    private init() {}

    /// 检查是否曾经添加过正版账户
    /// - Returns: 如果曾经添加过正版账户则返回 true
    func hasAddedPremiumAccount() -> Bool {
        return UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
    }

    /// 设置已添加正版账户标记
    func setPremiumAccountAdded() {
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
        Logger.shared.debug("已设置正版账户添加标记")
    }
}
