import Foundation

/// 用户基本信息存储管理器
/// 使用 UserDefaults (plist) 存储用户基本信息
class UserProfileStore {
    private let profilesKey = "userProfiles"

    // MARK: - Public Methods

    /// 加载所有用户基本信息
    /// - Returns: 用户基本信息数组
    func loadProfiles() -> [UserProfile] {
        guard let profilesData = UserDefaults.standard.data(forKey: profilesKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([UserProfile].self, from: profilesData)
        } catch {
            Logger.shared.error("加载用户基本信息失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 加载所有用户基本信息（抛出异常版本）
    /// - Returns: 用户基本信息数组
    /// - Throws: GlobalError 当操作失败时
    func loadProfilesThrowing() throws -> [UserProfile] {
        guard let profilesData = UserDefaults.standard.data(forKey: profilesKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([UserProfile].self, from: profilesData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "加载用户基本信息失败: \(error.localizedDescription)",
                i18nKey: "error.validation.user_profile_load_failed",
                level: .notification
            )
        }
    }

    /// 保存用户基本信息数组
    /// - Parameter profiles: 要保存的用户基本信息数组
    func saveProfiles(_ profiles: [UserProfile]) {
        do {
            try saveProfilesThrowing(profiles)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("保存用户基本信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 保存用户基本信息数组（抛出异常版本）
    /// - Parameter profiles: 要保存的用户基本信息数组
    /// - Throws: GlobalError 当操作失败时
    func saveProfilesThrowing(_ profiles: [UserProfile]) throws {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(profiles)
            UserDefaults.standard.set(encodedData, forKey: profilesKey)
            Logger.shared.debug("用户基本信息已保存")
        } catch {
            throw GlobalError.validation(
                chineseMessage: "保存用户基本信息失败: \(error.localizedDescription)",
                i18nKey: "error.validation.user_profile_save_failed",
                level: .notification
            )
        }
    }

    /// 添加用户基本信息
    /// - Parameter profile: 要添加的用户基本信息
    /// - Throws: GlobalError 当操作失败时
    func addProfile(_ profile: UserProfile) throws {
        var profiles = try loadProfilesThrowing()

        if profiles.contains(where: { $0.id == profile.id }) {
            throw GlobalError.player(
                chineseMessage: "用户已存在: \(profile.name)",
                i18nKey: "error.player.already_exists",
                level: .notification
            )
        }

        // 如果是第一个用户，设置为当前用户
        if profiles.isEmpty {
            var newProfile = profile
            newProfile.isCurrent = true
            profiles.append(newProfile)
        } else {
            profiles.append(profile)
        }

        try saveProfilesThrowing(profiles)
        Logger.shared.debug("已添加新用户: \(profile.name)")
    }

    /// 更新用户基本信息
    /// - Parameter profile: 更新后的用户基本信息
    /// - Throws: GlobalError 当操作失败时
    func updateProfile(_ profile: UserProfile) throws {
        var profiles = try loadProfilesThrowing()

        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw GlobalError.player(
                chineseMessage: "要更新的用户不存在: \(profile.name)",
                i18nKey: "error.player.not_found_for_update",
                level: .notification
            )
        }

        profiles[index] = profile
        try saveProfilesThrowing(profiles)
        Logger.shared.debug("已更新用户信息: \(profile.name)")
    }

    /// 删除用户基本信息
    /// - Parameter id: 要删除的用户ID
    /// - Throws: GlobalError 当操作失败时
    func deleteProfile(byID id: String) throws {
        var profiles = try loadProfilesThrowing()
        let initialCount = profiles.count

        // 检查要删除的用户是否为当前用户
        let isDeletingCurrentUser = profiles.contains { $0.id == id && $0.isCurrent }

        profiles.removeAll { $0.id == id }

        if profiles.count < initialCount {
            // 如果删除的是当前用户，需要设置新的当前用户
            if isDeletingCurrentUser && !profiles.isEmpty {
                profiles[0].isCurrent = true
                Logger.shared.debug("当前用户被删除，已设置第一个用户为当前用户: \(profiles[0].name)")
            }

            try saveProfilesThrowing(profiles)
            Logger.shared.debug("已删除用户 (ID: \(id))")
        } else {
            throw GlobalError.player(
                chineseMessage: "用户不存在: \(id)",
                i18nKey: "error.player.not_found",
                level: .notification
            )
        }
    }

    /// 检查用户是否存在
    /// - Parameter id: 要检查的用户ID
    /// - Returns: 如果存在则返回 true，否则返回 false
    func profileExists(id: String) -> Bool {
        do {
            let profiles = try loadProfilesThrowing()
            return profiles.contains { $0.id == id }
        } catch {
            Logger.shared.error("检查用户存在性失败: \(error.localizedDescription)")
            return false
        }
    }
}
