//
//  PlayerSettingsManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import SwiftUI

/// Manages player-related settings persisted in `UserDefaults`.
@Observable
final class PlayerSettingsManager {
    /// A Combine subject that fires when presence notification setting changes,
    /// for consumers that need Combine streams (e.g. MinecraftFriendsPresencePollingCoordinator).
    let presenceNotificationsDidChange = PassthroughSubject<Void, Never>()

    /// A Boolean value indicating whether offline login is allowed in the launcher.
    var enableOfflineLogin: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableOfflineLogin) {
        didSet { Defaults.save(enableOfflineLogin, forKey: AppConstants.UserDefaultsKeys.enableOfflineLogin) }
    }

    /// A Boolean value indicating whether to use an ephemeral browser session for web login.
    var enableEphemeralWebLogin: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableEphemeralWebLogin) {
        didSet { Defaults.save(enableEphemeralWebLogin, forKey: AppConstants.UserDefaultsKeys.enableEphemeralWebLogin) }
    }

    /// The default Yggdrasil authentication server base URL for offline login.
    var defaultYggdrasilServerBaseURL: String = Defaults.loadString(forKey: AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL) {
        didSet { Defaults.save(defaultYggdrasilServerBaseURL, forKey: AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL) }
    }

    /// A Boolean value indicating whether the history skin library is enabled.
    ///
    /// This feature is only available for premium (Mojang/Microsoft) accounts.
    var enableHistorySkinLibrary: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableHistorySkinLibrary) {
        didSet { Defaults.save(enableHistorySkinLibrary, forKey: AppConstants.UserDefaultsKeys.enableHistorySkinLibrary) }
    }

    /// A Boolean value indicating whether Minecraft friend presence notifications are enabled.
    ///
    /// When enabled, the launcher polls for friend online/offline/invite status
    /// in the background while a Microsoft account is selected.
    var enableMinecraftFriendsPresenceNotifications: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications) {
        didSet {
            Defaults.save(enableMinecraftFriendsPresenceNotifications, forKey: AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications)
            presenceNotificationsDidChange.send()
        }
    }
}
