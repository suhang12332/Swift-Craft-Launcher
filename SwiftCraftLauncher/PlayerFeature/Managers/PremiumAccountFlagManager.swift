//
//  PremiumAccountFlagManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Tracks whether a premium (Mojang/Microsoft) account has ever been added.
///
/// This flag determines whether offline account creation is permitted.
@Observable
class PremiumAccountFlagManager {
    init() { }

    /// A Boolean value indicating whether a premium account has been added previously.
    func hasAddedPremiumAccount() -> Bool {
        Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
    }

    /// Records that a premium account has been added.
    func setPremiumAccountAdded() {
        Defaults.save(true, forKey: AppConstants.UserDefaultsKeys.hasAddedPremiumAccount)
        AppLog.player.debug("Premium account added flag set")
    }

    /// Whether offline account creation is permitted.
    /// Returns `true` if a premium account has been added or the user is not on a foreign IP.
    func canAddOfflineAccount(ipLocationService: IPLocationService) async -> Bool {
        if hasAddedPremiumAccount() {
            return true
        }
        let foreign = (try? await ipLocationService.isForeignIPThrowing()) ?? true
        return !foreign
    }
}
