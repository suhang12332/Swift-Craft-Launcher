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

    /// 账号认证方式;离线账号与待迁移的旧档案为 `nil`。
    ///
    /// 非 `nil` 时,该账号的凭据保存在统一钥匙串存储
    /// (`AccountCredentialStore`)中,按 `authMethod` 命名空间隔离。
    var authMethod: AccountAuthMethod?

    /// Yggdrasil 玩家关联的认证服务器地址(预设或自定义服务器的 baseURL)。
    var yggdrasilServerBaseURL: String?

    /// Creates a user profile.
    /// - Parameters:
    ///   - id: The unique user identifier.
    ///   - name: The display name.
    ///   - avatar: The avatar image name or URL.
    ///   - lastPlayed: The last play time. Defaults to the current date.
    ///   - isCurrent: Whether this is the current user. Defaults to `false`.
    ///   - authMethod: The authentication method. Defaults to `nil` (offline).
    ///   - yggdrasilServerBaseURL: The associated Yggdrasil server URL. Defaults to `nil`.
    init(
        id: String,
        name: String,
        avatar: String,
        lastPlayed: Date = Date(),
        isCurrent: Bool = false,
        authMethod: AccountAuthMethod? = nil,
        yggdrasilServerBaseURL: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastPlayed = lastPlayed
        self.isCurrent = isCurrent
        self.authMethod = authMethod
        self.yggdrasilServerBaseURL = yggdrasilServerBaseURL
    }
}
