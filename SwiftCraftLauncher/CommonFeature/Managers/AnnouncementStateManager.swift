import Foundation

/// 公告状态管理器
/// 管理按版本记录的公告已读状态
@MainActor
class AnnouncementStateManager {
    static let shared = AnnouncementStateManager()

    private init() {}

    private let defaults = UserDefaults.standard

    /// 当前版本公告是否已读
    func isAnnouncementAcknowledgedForCurrentVersion() -> Bool {
        let currentVersion = Bundle.main.appVersion
        return acknowledgedVersion() == currentVersion
    }

    /// 标记当前版本公告为已读
    func markAnnouncementAcknowledgedForCurrentVersion() {
        let currentVersion = Bundle.main.appVersion
        defaults.set(
            currentVersion,
            forKey: AppConstants.UserDefaultsKeys.acknowledgedAnnouncementVersion
        )
    }

    private func acknowledgedVersion() -> String? {
        defaults.string(
            forKey: AppConstants.UserDefaultsKeys.acknowledgedAnnouncementVersion
        )
    }
}
