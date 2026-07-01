//
//  PremiumAccountFlagManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tracks whether a premium (Mojang/Microsoft) account has ever been added.
///
/// This flag determines whether offline account creation is permitted.
@MainActor
class PremiumAccountFlagManager {
    static let shared = PremiumAccountFlagManager()

    private init() { }

    /// A Boolean value indicating whether a premium account has been added previously.
    func hasAddedPremiumAccount() -> Bool {
        UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
    }

    /// Marks that a premium account has been added.
    func setPremiumAccountAdded() {
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
        AppLog.player.debug("已设置正版账户添加标记")
    }
}
