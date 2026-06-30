//
//  UserProfile.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A user profile stored in the local plist file.
struct UserProfile: Identifiable, Codable, Equatable {
    /// The unique user identifier.
    let id: String

    /// The display name.
    let name: String

    /// The avatar image name or path.
    let avatar: String

    /// The last time the user played.
    var lastPlayed: Date

    /// Whether this is the currently selected user.
    var isCurrent: Bool

    /// Creates a user profile.
    /// - Parameters:
    ///   - id: The unique user identifier.
    ///   - name: The display name.
    ///   - avatar: The avatar image name or path.
    ///   - lastPlayed: The last play time. Defaults to the current date.
    ///   - isCurrent: Whether this is the current user. Defaults to `false`.
    init(
        id: String,
        name: String,
        avatar: String,
        lastPlayed: Date = Date(),
        isCurrent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
    }
}
