//
//  AnnouncementStateManager.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tracks whether the current version's announcement has been acknowledged.
@MainActor
class AnnouncementStateManager {
    init() { }

    private let defaults = UserDefaults.standard

    /// Returns whether the announcement for the current app version has been acknowledged.
    func isAnnouncementAcknowledgedForCurrentVersion() -> Bool {
        let currentVersion = Bundle.main.appVersion
        return acknowledgedVersion() == currentVersion
    }

    /// Records that the announcement for the current app version was acknowledged.
    func markAnnouncementAcknowledgedForCurrentVersion() {
        let currentVersion = Bundle.main.appVersion
        defaults.set(
            currentVersion,
            forKey: AppConstants.UserDefaultsKeys.acknowledgedAnnouncementVersion,
        )
    }

    private func acknowledgedVersion() -> String? {
        defaults.string(
            forKey: AppConstants.UserDefaultsKeys.acknowledgedAnnouncementVersion,
        )
    }
}
