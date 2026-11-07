//
//  Notification+Name.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Centralized notification name definitions for the application.
extension Notification.Name {
    static let playerUpdated = Notification.Name("SwiftCraftLauncher.PlayerUpdated")

    /// Posted when the Minecraft friends account preferences are updated on the server.
    static let minecraftFriendsAccountPreferencesDidChange = Notification.Name("SwiftCraftLauncher.MinecraftFriendsAccountPreferencesDidChange")

    static let localResourceImported = Notification.Name("SwiftCraftLauncher.LocalResourceImported")
}
