//
//  OfflineUserServerMap.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Maps offline player IDs to their Yggdrasil authentication profiles.
enum OfflineUserServerMap {
    private static func loadMap() -> [String: YggdrasilProfile] {
        guard let data = UserDefaults.standard.data(forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap),
              let map = try? JSONDecoder().decode([String: YggdrasilProfile].self, from: data) else {
            return [:]
        }
        return map
    }

    /// Associates a Yggdrasil profile with the specified user.
    static func setServer(_ profile: YggdrasilProfile) {
        var map = loadMap()
        map[profile.id] = profile
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
            AppLog.common.info("Updated Yggdrasil profile for user \(profile.id), server: \(profile.serverBaseURL)")
        } else {
            AppLog.common.error("Failed to encode Yggdrasil profile for user \(profile.id)")
        }
    }

    /// Removes the Yggdrasil profile for the specified user.
    /// - Parameter userId: The player identifier.
    static func removeServer(for userId: String) {
        var map = loadMap()
        map.removeValue(forKey: userId)
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
        }
    }

    /// Returns the Yggdrasil profile for the specified user.
    /// - Parameter userId: The player identifier.
    /// - Returns: The associated profile, or `nil` if none exists.
    static func serverKey(for userId: String) -> YggdrasilProfile? {
        loadMap()[userId]
    }

    /// Indicates whether the specified user has an associated Yggdrasil profile.
    static func contains(userId: String) -> Bool {
        loadMap()[userId] != nil
    }
}
