//
//  PlayerDataManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Coordinates player data across ``UserProfileStore`` and ``AuthCredentialStore``.
///
/// Profiles are persisted to `UserDefaults` (plist) and credentials are stored in the system Keychain.
class PlayerDataManager {
    private let profileStore: UserProfileStore
    private let credentialStore = AuthCredentialStore()

    init() {
        profileStore = UserProfileStore()
    }

    /// Adds a new player with the specified properties.
    ///
    /// - Parameters:
    ///   - name: The player's display name.
    ///   - uuid: A unique identifier. An offline UUID is generated when this is `nil`.
    ///   - isOnline: A Boolean value indicating whether this is an online account.
    ///   - avatarName: The avatar image name or URL.
    ///   - accToken: The access token for online authentication.
    ///   - refreshToken: The refresh token for online authentication.
    ///   - xuid: The Xbox user identifier.
    /// - Throws: A `GlobalError` if the player already exists or creation fails.
    func addPlayer(
        name: String,
        uuid: String? = nil,
        isOnline: Bool,
        avatarName: String,
        accToken: String = "",
        refreshToken: String = "",
        xuid: String = "",
    ) throws {
        let players = try loadPlayersThrowing()

        if try playerExistsThrowing(name: name) {
            throw GlobalError.player(
                i18nKey: "error.player.already_exists",
                level: .notification,
                message: "Player with name \"\(name)\" already exists",
            )
        }

        do {
            let credential: AuthCredential?
            if isOnline, !accToken.isEmpty {
                let tempId: String
                if let providedUUID = uuid {
                    tempId = providedUUID
                } else {
                    tempId = try PlayerUtils.generateOfflineUUID(for: name)
                }
                credential = AuthCredential(
                    userId: tempId,
                    accessToken: accToken,
                    refreshToken: refreshToken,
                    xuid: xuid,
                )
            } else {
                credential = nil
            }

            let newPlayer = try Player(
                name: name,
                uuid: uuid,
                avatar: avatarName.isEmpty ? nil : avatarName,
                credential: credential,
                isCurrent: players.isEmpty,
            )

            try profileStore.addProfile(newPlayer.profile)

            if let credential = newPlayer.credential {
                if !credentialStore.saveCredential(credential) {
                    try? profileStore.deleteProfile(byID: newPlayer.id)
                    throw GlobalError.validation(
                        i18nKey: "error.validation.credential_save_failed",
                        level: .notification,
                        message: "Failed to save credential to Keychain for player \"\(name)\" (ID: \(newPlayer.id))",
                    )
                }
            }

            AppLog.player.debug("New player added: \(name)")
        } catch {
            throw GlobalError.player(
                i18nKey: "error.player.creation_failed",
                level: .notification,
                message: "Failed to create player \"\(name)\": \(error.localizedDescription)",
            )
        }
    }

    /// Loads all saved players, throwing on failure.
    ///
    /// - Returns: An array of players.
    /// - Throws: A `GlobalError` if loading fails.
    func loadPlayersThrowing() throws -> [Player] {
        let profiles = try profileStore.loadProfilesThrowing()

        return profiles.map { profile in
            Player(profile: profile, credential: nil)
        }
    }

    /// Loads the authentication credential for the specified player.
    ///
    /// - Parameter userId: The player's identifier.
    /// - Returns: The credential, or `nil` if none exists.
    func loadCredential(userId: String) -> AuthCredential? {
        credentialStore.loadCredential(userId: userId)
    }

    /// Checks whether a player with the given name already exists (case-insensitive).
    ///
    /// - Parameter name: The name to check.
    /// - Returns: `true` if a matching player exists.
    /// - Throws: A `GlobalError` if the player list cannot be loaded.
    func playerExistsThrowing(name: String) throws -> Bool {
        let players = try loadPlayersThrowing()
        return players.contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Deletes a player by identifier, including their credential and server mappings.
    ///
    /// When the current player is deleted, the first remaining player becomes current.
    ///
    /// - Parameter id: The identifier of the player to delete.
    /// - Throws: A `GlobalError` if the player cannot be found or deletion fails.
    func deletePlayer(byID id: String) throws {
        let players = try loadPlayersThrowing()
        let initialCount = players.count
        let isDeletingCurrentPlayer = players.contains { $0.id == id && $0.isCurrent }

        try profileStore.deleteProfile(byID: id)
        _ = credentialStore.deleteCredential(userId: id)
        OfflineUserServerMap.removeServer(for: id)

        if initialCount > 0 {
            if isDeletingCurrentPlayer {
                let remainingPlayers = try loadPlayersThrowing()
                if !remainingPlayers.isEmpty {
                    var firstPlayer = remainingPlayers[0]
                    firstPlayer.isCurrent = true
                    try updatePlayer(firstPlayer)
                    AppLog.player.debug("Current player deleted, set first player as current: \(firstPlayer.name)")
                }
            }
            AppLog.player.debug("Player deleted (ID: \(id))")
        }
    }

    /// Saves an array of players, throwing on failure.
    ///
    /// Profiles and credentials are persisted separately. Orphaned credentials
    /// (those whose associated profile no longer exists) are cleaned up.
    ///
    /// - Parameter players: The players to save.
    /// - Throws: A `GlobalError` if saving fails.
    func savePlayersThrowing(_ players: [Player]) throws {
        var profiles: [UserProfile] = []
        var credentials: [AuthCredential] = []

        for player in players {
            profiles.append(player.profile)
            if let credential = player.credential {
                credentials.append(credential)
            }
        }

        try profileStore.saveProfilesThrowing(profiles)

        for credential in credentials where !credentialStore.saveCredential(credential) {
            throw GlobalError.validation(
                i18nKey: "error.validation.credential_save_failed",
                level: .notification,
                message: "Failed to save credential to Keychain for userId: \(credential.userId)",
            )
        }

        let existingProfileIds = Set(profiles.map(\.id))
        let allCredentials = try loadPlayersThrowing().compactMap(\.credential)
        for credential in allCredentials where !existingProfileIds.contains(credential.userId) {
            _ = credentialStore.deleteCredential(userId: credential.userId)
        }

        AppLog.player.debug("Player data saved")
    }

    /// Updates an existing player's profile and credential.
    ///
    /// - Parameter updatedPlayer: The player with updated values.
    /// - Throws: A `GlobalError` if the update fails.
    func updatePlayer(_ updatedPlayer: Player) throws {
        try profileStore.updateProfile(updatedPlayer.profile)

        if let credential = updatedPlayer.credential {
            if !credentialStore.saveCredential(credential) {
                throw GlobalError.validation(
                    i18nKey: "error.validation.credential_update_failed",
                    level: .notification,
                    message: "Failed to save updated credential to Keychain for player \"\(updatedPlayer.name)\" (ID: \(updatedPlayer.id))",
                )
            }
        } else {
            AppLog.player.debug("No new credentials provided, keeping existing Keychain state - userId: \(updatedPlayer.id)")
        }

        AppLog.player.debug("Player info updated: \(updatedPlayer.name)")
    }
}
