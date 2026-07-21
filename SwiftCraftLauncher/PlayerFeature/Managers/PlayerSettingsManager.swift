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

    /// The identifier of the currently selected player.
    var currentPlayerId: String {
        didSet { UserDefaults.standard.set(currentPlayerId, forKey: AppConstants.UserDefaultsKeys.currentPlayerId) }
    }

    /// A Boolean value indicating whether offline login is allowed in the launcher.
    var enableOfflineLogin: Bool {
        didSet { UserDefaults.standard.set(enableOfflineLogin, forKey: AppConstants.UserDefaultsKeys.enableOfflineLogin) }
    }

    /// A Boolean value indicating whether to use an ephemeral browser session for web login.
    var enableEphemeralWebLogin: Bool {
        didSet { UserDefaults.standard.set(enableEphemeralWebLogin, forKey: AppConstants.UserDefaultsKeys.enableEphemeralWebLogin) }
    }

    /// The default Yggdrasil authentication server base URL for offline login.
    var defaultYggdrasilServerBaseURL: String {
        didSet { UserDefaults.standard.set(defaultYggdrasilServerBaseURL, forKey: AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL) }
    }

    /// A Boolean value indicating whether the history skin library is enabled.
    ///
    /// This feature is only available for premium (Mojang/Microsoft) accounts.
    var enableHistorySkinLibrary: Bool {
        didSet { UserDefaults.standard.set(enableHistorySkinLibrary, forKey: AppConstants.UserDefaultsKeys.enableHistorySkinLibrary) }
    }

    /// A Boolean value indicating whether Minecraft friend presence notifications are enabled.
    ///
    /// When enabled, the launcher polls for friend online/offline/invite status
    /// in the background while a Microsoft account is selected.
    var enableMinecraftFriendsPresenceNotifications: Bool {
        didSet {
            UserDefaults.standard.set(enableMinecraftFriendsPresenceNotifications, forKey: AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications)
            presenceNotificationsDidChange.send()
        }
    }

    init() {
        let d = UserDefaults.standard
        currentPlayerId = d.string(forKey: AppConstants.UserDefaultsKeys.currentPlayerId) ?? ""
        enableOfflineLogin = d.bool(forKey: AppConstants.UserDefaultsKeys.enableOfflineLogin)
        enableEphemeralWebLogin = d.bool(forKey: AppConstants.UserDefaultsKeys.enableEphemeralWebLogin)
        defaultYggdrasilServerBaseURL = d.string(forKey: AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL) ?? ""
        enableHistorySkinLibrary = d.bool(forKey: AppConstants.UserDefaultsKeys.enableHistorySkinLibrary)
        enableMinecraftFriendsPresenceNotifications = d.bool(forKey: AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications)
    }
}
