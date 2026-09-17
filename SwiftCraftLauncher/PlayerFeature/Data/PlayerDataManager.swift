//
//  PlayerDataManager.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Coordinates player data across ``UserProfileStore`` and ``AccountCredentialStore``.
///
/// Profiles are persisted to `UserDefaults` (plist); all authentication credentials
/// (Microsoft / Yggdrasil OAuth / Yggdrasil password) are stored uniformly in the
/// system Keychain, namespaced by auth method.
class PlayerDataManager {
    private let profileStore: UserProfileStore
    private let credentialStore = AccountCredentialStore()

    init() {
        profileStore = UserProfileStore()
        migrateLegacyCredentialsIfNeeded()
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
        let credential: AccountCredential?
        if isOnline, !accToken.isEmpty {
            let tempId = try uuid ?? PlayerUtils.generateOfflineUUID(for: name)
            credential = AccountCredential(
                userId: tempId,
                authMethod: .microsoft,
                accessToken: accToken,
                renewalSecret: refreshToken,
                xuid: xuid,
            )
        } else {
            credential = nil
        }

        try addAuthenticatedPlayer(
            name: name,
            uuid: uuid,
            avatarName: avatarName,
            credential: credential,
        )
    }

    /// Adds a player with a ready-made unified credential.
    ///
    /// The profile's `authMethod` is derived from the credential. The credential is
    /// written to the unified Keychain store; on failure the profile write is rolled back.
    ///
    /// - Parameters:
    ///   - name: The player's display name.
    ///   - uuid: A unique identifier for the player.
    ///   - avatarName: The avatar image name or URL.
    ///   - credential: The unified authentication credential.
    ///   - yggdrasilServerBaseURL: The associated Yggdrasil server URL, if any.
    /// - Throws: A `GlobalError` if the player already exists or creation fails.
    func addAuthenticatedPlayer(
        name: String,
        uuid: String?,
        avatarName: String,
        credential: AccountCredential?,
        yggdrasilServerBaseURL: String? = nil,
    ) throws {
        let players = try loadPlayersThrowing()

        // 同一角色(相同 UUID)再次添加:视为切换登录方式/刷新凭据,原位更新
        // 而不是按重名拒绝(例如同一皮肤站角色从 OAuth 切换到密码登录)。
        if let credential,
           let existing = players.first(where: { $0.id == credential.userId }) {
            var profile = existing.profile
            profile.name = name
            if !avatarName.isEmpty {
                profile.avatar = avatarName
            }
            profile.authMethod = credential.authMethod
            if let yggdrasilServerBaseURL {
                profile.yggdrasilServerBaseURL = yggdrasilServerBaseURL
            }

            let updated = Player(profile: profile, credential: credential)
            try updatePlayer(updated)
            NotificationCenter.default.post(
                name: .playerUpdated,
                object: nil,
                userInfo: ["updatedPlayer": updated],
            )
            AppLog.player.debug("Existing player updated with new credential: \(name)")
            return
        }

        if try playerExistsThrowing(name: name) {
            throw GlobalError.player(
                i18nKey: "error.player.already_exists",
                level: .notification,
                message: "Player with name \"\(name)\" already exists",
            )
        }

        do {
            let newPlayer = try Player(
                name: name,
                uuid: uuid,
                avatar: avatarName.isEmpty ? nil : avatarName,
                credential: credential,
                isCurrent: players.isEmpty,
            )

            var profile = newPlayer.profile
            profile.yggdrasilServerBaseURL = yggdrasilServerBaseURL
            try profileStore.addProfile(profile)

            if let credential = newPlayer.credential {
                if !credentialStore.save(credential) {
                    try? profileStore.deleteProfile(byID: newPlayer.id)
                    throw GlobalError.validation(
                        i18nKey: "error.validation.credential_save_failed",
                        level: .notification,
                        message: "Failed to save credential to Keychain for player \"\(name)\" (ID: \(newPlayer.id))",
                    )
                }
            }

            AppLog.player.debug("New player added: \(name)")
        } catch let error as GlobalError {
            throw error
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
    /// Credentials are hydrated from the unified Keychain store so that callers
    /// see tokens without a second round-trip.
    ///
    /// - Returns: An array of players.
    /// - Throws: A `GlobalError` if loading fails.
    func loadPlayersThrowing() throws -> [Player] {
        let profiles = try profileStore.loadProfilesThrowing()

        return profiles.map { profile in
            let credential: AccountCredential?
            if let authMethod = profile.authMethod {
                credential = credentialStore.load(userId: profile.id, authMethod: authMethod)
            } else {
                credential = nil
            }
            return Player(profile: profile, credential: credential)
        }
    }

    /// Loads the authentication credential for the specified player.
    ///
    /// - Parameters:
    ///   - userId: The player's identifier.
    ///   - authMethod: The expected auth method. When `nil`, all methods are tried.
    /// - Returns: The credential, or `nil` if none exists.
    func loadCredential(userId: String, authMethod: AccountAuthMethod? = nil) -> AccountCredential? {
        if let authMethod {
            return credentialStore.load(userId: userId, authMethod: authMethod)
        }
        return credentialStore.loadAny(userId: userId)
    }

    /// Persists a credential to the unified Keychain store.
    /// - Returns: `true` if the credential was saved successfully.
    @discardableResult
    func saveCredential(_ credential: AccountCredential) -> Bool {
        credentialStore.save(credential)
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

    /// Deletes a player by identifier, including their credential.
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
        credentialStore.deleteAll(userId: id)

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
        var credentials: [AccountCredential] = []

        for player in players {
            profiles.append(player.profile)
            if let credential = player.credential {
                credentials.append(credential)
            }
        }

        try profileStore.saveProfilesThrowing(profiles)

        for credential in credentials where !credentialStore.save(credential) {
            throw GlobalError.validation(
                i18nKey: "error.validation.credential_save_failed",
                level: .notification,
                message: "Failed to save credential to Keychain for userId: \(credential.userId)",
            )
        }

        let existingProfileIds = Set(profiles.map(\.id))
        for credential in credentials where !existingProfileIds.contains(credential.userId) {
            credentialStore.deleteAll(userId: credential.userId)
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
            if !credentialStore.save(credential) {
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

    // MARK: - 旧存储一次性迁移

    /// 旧版钥匙串凭据结构,仅用于迁移解码。
    private struct LegacyAuthCredential: Codable {
        let userId: String
        let accessToken: String
        let refreshToken: String
        let xuid: String?
    }

    /// 旧版 `OfflineUserServerMap` 条目(含明文令牌),仅用于迁移解码。
    private struct LegacyYggdrasilProfile: Codable {
        let id: String
        let accessToken: String
        let refreshToken: String
        let serverBaseURL: String
    }

    /// 将旧版分散存储迁移到统一凭据存储(幂等,只执行一次)。
    ///
    /// - 旧微软凭据:单键钥匙串条目 → `microsoft.{userId}` 复合键条目。
    /// - 旧 Yggdrasil 映射:UserDefaults 明文令牌 → `yggdrasilOAuth.{userId}`
    ///   复合键条目,服务器关联写入档案,随后移除明文数据。
    /// - 所有条目"先确认写入成功、再删除旧数据";档案解码失败时保留旧数据
    ///   与未迁移标记,下次启动重试。
    private func migrateLegacyCredentialsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: AppConstants.UserDefaultsKeys.accountCredentialMigrationVersion) < 1 else {
            return
        }

        // 1. 旧 Yggdrasil 映射拆解
        var yggServerByUserId: [String: String] = [:]
        if let data = defaults.data(forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap),
           let legacyMap = try? JSONDecoder().decode([String: LegacyYggdrasilProfile].self, from: data) {
            for (userId, legacy) in legacyMap {
                if credentialStore.load(userId: userId, authMethod: .yggdrasilOAuth) == nil {
                    _ = credentialStore.save(AccountCredential(
                        userId: userId,
                        authMethod: .yggdrasilOAuth,
                        accessToken: legacy.accessToken,
                        renewalSecret: legacy.refreshToken,
                    ))
                }
                yggServerByUserId[userId] = legacy.serverBaseURL
            }
        }

        // 2. 档案补齐认证方式,并迁移旧微软钥匙串条目
        let profiles: [UserProfile]
        do {
            profiles = try profileStore.loadProfilesThrowing()
        } catch {
            // 档案损坏时保留旧数据与未迁移标记,下次启动重试。
            AppLog.player.error("Credential migration skipped, profiles unavailable: \(error.localizedDescription)")
            return
        }

        var updatedProfiles: [UserProfile] = []
        for var profile in profiles {
            if profile.authMethod == nil, let serverURL = yggServerByUserId[profile.id] {
                profile.authMethod = .yggdrasilOAuth
                profile.yggdrasilServerBaseURL = serverURL
            }

            if let data = KeychainManager.load(account: profile.id, key: AppConstants.KeychainKeys.authCredential),
               let legacy = try? JSONDecoder().decode(LegacyAuthCredential.self, from: data) {
                if credentialStore.load(userId: profile.id, authMethod: .microsoft) == nil {
                    _ = credentialStore.save(AccountCredential(
                        userId: profile.id,
                        authMethod: .microsoft,
                        accessToken: legacy.accessToken,
                        renewalSecret: legacy.refreshToken,
                        xuid: legacy.xuid,
                    ))
                }
                KeychainManager.delete(account: profile.id, key: AppConstants.KeychainKeys.authCredential)
                if profile.authMethod == nil {
                    profile.authMethod = .microsoft
                }
            }

            updatedProfiles.append(profile)
        }

        try? profileStore.saveProfilesThrowing(updatedProfiles)

        // 3. 明文映射已拆解完毕,移除旧数据并标记迁移完成
        if !yggServerByUserId.isEmpty {
            defaults.removeObject(forKey: AppConstants.UserDefaultsKeys.offlineUserServerMap)
        }
        defaults.set(1, forKey: AppConstants.UserDefaultsKeys.accountCredentialMigrationVersion)
        AppLog.player.info("Legacy credential migration completed")
    }
}
