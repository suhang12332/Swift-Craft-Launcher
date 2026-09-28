//
//  PlayerModels.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents a player by combining a ``UserProfile`` with an optional ``AccountCredential``.
///
/// `Player` values are not stored directly; they are constructed from ``UserProfileStore``
/// and ``AccountCredentialStore`` at the point of use.
struct Player: Identifiable, Equatable, Codable {
    /// The player's profile information.
    var profile: UserProfile

    /// The player's unified authentication credential, or `nil` for offline-only accounts.
    var credential: AccountCredential?

    /// The unique identifier for this player.
    var id: String { profile.id }

    /// The display name of this player.
    var name: String { profile.name }

    /// The avatar image name or URL.
    var avatarName: String { profile.avatar }

    /// The last time this player was active.
    var lastPlayed: Date {
        get { profile.lastPlayed }
        set { profile.lastPlayed = newValue }
    }

    /// A Boolean value indicating whether this is the currently selected player.
    var isCurrent: Bool {
        get { profile.isCurrent }
        set { profile.isCurrent = newValue }
    }

    /// 账号的认证方式;离线账号为 `nil`。
    var authMethod: AccountAuthMethod? { profile.authMethod ?? credential?.authMethod }

    /// Yggdrasil 玩家关联的认证服务器地址。
    var yggdrasilServerBaseURL: String? { profile.yggdrasilServerBaseURL }

    /// A Boolean value indicating whether this is a Microsoft-authenticated account.
    ///
    /// 仅微软账号走启动前的正版令牌刷新链;Yggdrasil 账号(无论 OAuth
    /// 还是密码登录)由各自的续期流程处理。
    var isOnlineAccount: Bool {
        authMethod == .microsoft
    }

    /// A Boolean value indicating whether the account is authenticated against
    /// a Yggdrasil-compatible server (OAuth or password login).
    var isYggdrasilAccount: Bool {
        authMethod == .yggdrasilOAuth || authMethod == .yggdrasilPassword
    }

    /// A Boolean value indicating whether the avatar is hosted remotely.
    var isRemote: Bool {
        profile.avatar.hasPrefix("http://") || profile.avatar.hasPrefix("https://")
    }

    /// The access token used for authentication.
    var authAccessToken: String {
        credential?.accessToken ?? ""
    }

    /// The refresh token used to renew authentication (Microsoft / Yggdrasil OAuth).
    var authRefreshToken: String {
        credential?.oauthRefreshToken ?? ""
    }

    /// The Xbox user identifier associated with this account.
    var authXuid: String { credential?.microsoftXuid ?? "" }

    /// Creates a player with the given profile and optional credential.
    ///
    /// - Parameters:
    ///   - profile: The player's profile information.
    ///   - credential: The authentication credential. Pass `nil` for offline-only accounts.
    init(profile: UserProfile, credential: AccountCredential? = nil) {
        self.profile = profile
        self.credential = credential
    }

    /// Creates a player from individual property values.
    ///
    /// This initializer generates an offline UUID when no `uuid` is provided and selects
    /// a default avatar for offline accounts.
    ///
    /// - Parameters:
    ///   - name: The player's display name.
    ///   - uuid: A unique identifier for the player. A UUID is generated when this is `nil`.
    ///   - avatar: An avatar name or URL. A default is used when this is `nil`.
    ///   - credential: An authentication credential for online accounts.
    ///   - lastPlayed: The last active date. Defaults to the current date.
    ///   - isCurrent: A Boolean value indicating whether this is the current player.
    /// - Throws: ``PlayerError`` if the player ID cannot be generated.
    init(
        name: String,
        uuid: String? = nil,
        avatar: String? = nil,
        credential: AccountCredential? = nil,
        lastPlayed: Date = Date(),
        isCurrent: Bool = false,
    ) throws {
        let playerId: String
        if let providedUUID = uuid {
            playerId = providedUUID
        } else {
            playerId = try PlayerUtils.generateOfflineUUID(for: name)
        }

        let avatarName: String
        if let providedAvatar = avatar {
            avatarName = providedAvatar
        } else if credential != nil {
            avatarName = ""
        } else {
            avatarName = PlayerUtils.avatarName(for: playerId) ?? "steve"
        }

        let profile = UserProfile(
            id: playerId,
            name: name,
            avatar: avatarName,
            lastPlayed: lastPlayed,
            isCurrent: isCurrent,
            authMethod: credential?.authMethod,
        )

        self.profile = profile
        self.credential = credential
    }
}
