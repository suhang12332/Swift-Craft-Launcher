//
//  UserProfileStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Stores and manages user profiles using `UserDefaults`.
class UserProfileStore {
    private let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    /// Loads all stored user profiles.
    ///
    /// - Returns: An array of user profiles, or an empty array if none exist.
    func loadProfiles() -> [UserProfile] {
        guard let profilesData = UserDefaults.standard.data(forKey: AppConstants.UserDefaultsKeys.userProfiles) else {
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

    /// Loads all stored user profiles, throwing on failure.
    ///
    /// - Returns: An array of user profiles.
    /// - Throws: A `GlobalError` if the data cannot be decoded.
    func loadProfilesThrowing() throws -> [UserProfile] {
        guard let profilesData = UserDefaults.standard.data(forKey: AppConstants.UserDefaultsKeys.userProfiles) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([UserProfile].self, from: profilesData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "加载用户基本信息失败: \(error.localizedDescription)",
                i18nKey: "error.validation.user_profile_load_failed",
                level: .notification,
            )
        }
    }

    /// Saves an array of user profiles.
    ///
    /// - Parameter profiles: The profiles to save.
    func saveProfiles(_ profiles: [UserProfile]) {
        do {
            try saveProfilesThrowing(profiles)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("保存用户基本信息失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Saves an array of user profiles, throwing on failure.
    ///
    /// - Parameter profiles: The profiles to save.
    /// - Throws: A `GlobalError` if the data cannot be encoded.
    func saveProfilesThrowing(_ profiles: [UserProfile]) throws {
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(profiles)
            UserDefaults.standard.set(encodedData, forKey: AppConstants.UserDefaultsKeys.userProfiles)
            Logger.shared.debug("用户基本信息已保存")
        } catch {
            throw GlobalError.validation(
                chineseMessage: "保存用户基本信息失败: \(error.localizedDescription)",
                i18nKey: "error.validation.user_profile_save_failed",
                level: .notification,
            )
        }
    }

    /// Adds a new user profile.
    ///
    /// If this is the first profile, it is automatically marked as the current profile.
    ///
    /// - Parameter profile: The profile to add.
    /// - Throws: A `GlobalError` if a profile with the same identifier already exists.
    func addProfile(_ profile: UserProfile) throws {
        var profiles = try loadProfilesThrowing()

        if profiles.contains(where: { $0.id == profile.id }) {
            throw GlobalError.player(
                chineseMessage: "用户已存在: \(profile.name)",
                i18nKey: "error.player.already_exists",
                level: .notification,
            )
        }

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

    /// Updates an existing user profile.
    ///
    /// - Parameter profile: The updated profile.
    /// - Throws: A `GlobalError` if the profile cannot be found.
    func updateProfile(_ profile: UserProfile) throws {
        var profiles = try loadProfilesThrowing()

        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw GlobalError.player(
                chineseMessage: "要更新的用户不存在: \(profile.name)",
                i18nKey: "error.player.not_found_for_update",
                level: .notification,
            )
        }

        profiles[index] = profile
        try saveProfilesThrowing(profiles)
        Logger.shared.debug("已更新用户信息: \(profile.name)")
    }

    /// Deletes a user profile by its identifier.
    ///
    /// When the current profile is deleted, the first remaining profile becomes current.
    ///
    /// - Parameter id: The identifier of the profile to delete.
    /// - Throws: A `GlobalError` if the profile cannot be found.
    func deleteProfile(byID id: String) throws {
        var profiles = try loadProfilesThrowing()
        let initialCount = profiles.count
        let isDeletingCurrentUser = profiles.contains { $0.id == id && $0.isCurrent }

        profiles.removeAll { $0.id == id }

        if profiles.count < initialCount {
            if isDeletingCurrentUser, !profiles.isEmpty {
                profiles[0].isCurrent = true
                Logger.shared.debug("当前用户被删除，已设置第一个用户为当前用户: \(profiles[0].name)")
            }

            try saveProfilesThrowing(profiles)
            Logger.shared.debug("已删除用户 (ID: \(id))")
        } else {
            throw GlobalError.player(
                chineseMessage: "用户不存在: \(id)",
                i18nKey: "error.player.not_found",
                level: .notification,
            )
        }
    }

    /// Checks whether a profile with the given identifier exists.
    ///
    /// - Parameter id: The identifier to check.
    /// - Returns: `true` if a matching profile exists.
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
