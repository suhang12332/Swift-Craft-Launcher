//
//  AuthCredential.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// An authentication credential stored in the system keychain.
struct AuthCredential: Codable, Equatable {
    /// The user identifier matching the corresponding `UserProfile.id`.
    let userId: String

    /// The OAuth access token used for API requests.
    var accessToken: String

    /// The OAuth refresh token used to obtain a new access token.
    var refreshToken: String

    /// The Xbox Live user identifier (XUID).
    var xuid: String

    /// Creates an authentication credential.
    /// - Parameters:
    ///   - userId: The user identifier.
    ///   - accessToken: The OAuth access token.
    ///   - refreshToken: The OAuth refresh token.
    ///   - xuid: The Xbox Live user identifier. Defaults to an empty string.
    init(
        userId: String,
        accessToken: String,
        refreshToken: String,
        xuid: String = ""
    ) {
        self.userId = userId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.xuid = xuid
    }
}
