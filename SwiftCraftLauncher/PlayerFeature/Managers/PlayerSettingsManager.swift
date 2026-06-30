//
//  PlayerSettingsManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages player-related settings persisted in `UserDefaults` via `@AppStorage`.
class PlayerSettingsManager: ObservableObject {
    static let shared = PlayerSettingsManager()

    /// The identifier of the currently selected player.
    @AppStorage(AppConstants.UserDefaultsKeys.currentPlayerId)
    var currentPlayerId: String = "" {
        didSet { objectWillChange.send() }
    }

    /// A Boolean value indicating whether offline login is allowed in the launcher.
    @AppStorage(AppConstants.UserDefaultsKeys.enableOfflineLogin)
    var enableOfflineLogin: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// A Boolean value indicating whether to use an ephemeral browser session for web login.
    @AppStorage(AppConstants.UserDefaultsKeys.enableEphemeralWebLogin)
    var enableEphemeralWebLogin: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// The default Yggdrasil authentication server base URL for offline login.
    @AppStorage(AppConstants.UserDefaultsKeys.defaultYggdrasilServerBaseURL)
    var defaultYggdrasilServerBaseURL: String = "" {
        didSet { objectWillChange.send() }
    }

    /// A Boolean value indicating whether the history skin library is enabled.
    ///
    /// This feature is only available for premium (Mojang/Microsoft) accounts.
    @AppStorage(AppConstants.UserDefaultsKeys.enableHistorySkinLibrary)
    var enableHistorySkinLibrary: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// A Boolean value indicating whether Minecraft friend presence notifications are enabled.
    ///
    /// When enabled, the launcher polls for friend online/offline/invite status
    /// in the background while a Microsoft account is selected.
    @AppStorage(AppConstants.UserDefaultsKeys.enableMinecraftFriendsPresenceNotifications)
    var enableMinecraftFriendsPresenceNotifications: Bool = false {
        didSet { objectWillChange.send() }
    }

    private init() { }
}
