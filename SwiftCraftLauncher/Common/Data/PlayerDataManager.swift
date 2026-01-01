import Foundation

/// 玩家数据管理器
/// 使用 UserProfileStore (plist) 和 AuthCredentialStore (Keychain) 分离存储
class PlayerDataManager {
    private let profileStore = UserProfileStore()
    private let credentialStore = AuthCredentialStore()

    // MARK: - Public Methods

    /// 添加新玩家
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID，如果为nil则生成离线UUID
    ///   - isOnline: 是否为在线账户
    ///   - avatarName: 头像名称
    ///   - accToken: 访问令牌，默认为空字符串
    ///   - refreshToken: 刷新令牌，默认为空字符串
    ///   - xuid: Xbox用户ID，默认为空字符串
    ///   - expiresAt: 令牌过期时间，可选
    ///   - yggdrasilServerURL: Yggdrasil 服务器基础URL，可选
    /// - Throws: GlobalError 当操作失败时
    func addPlayer(
        name: String,
        uuid: String? = nil,
        isOnline: Bool,
        avatarName: String,
        accToken: String = "",
        refreshToken: String = "",
        xuid: String = "",
        expiresAt: Date? = nil,
        yggdrasilServerURL: String? = nil
    ) throws {
        let players = try loadPlayersThrowing()

        if playerExists(name: name) {
            throw GlobalError.player(
                chineseMessage: "玩家已存在: \(name)",
                i18nKey: "error.player.already_exists",
                level: .notification
            )
        }

        do {
            // 创建 Player 对象
            let credential: AuthCredential?
            if isOnline && !accToken.isEmpty {
                // 需要先创建 Player 来获取 ID，但这里我们先创建 profile
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
                    expiresAt: expiresAt,
                    xuid: xuid,
                    yggdrasilServerURL: yggdrasilServerURL
                )
            } else {
                credential = nil
            }

            let newPlayer = try Player(
                name: name,
                uuid: uuid,
                avatar: avatarName.isEmpty ? nil : avatarName,
                credential: credential,
                isCurrent: players.isEmpty
            )

            // 保存 profile
            try profileStore.addProfile(newPlayer.profile)

            // 如果有 credential，保存到 Keychain
            if let credential = newPlayer.credential {
                if !credentialStore.saveCredential(credential) {
                    // 如果保存 credential 失败，回滚 profile
                    try? profileStore.deleteProfile(byID: newPlayer.id)
                    throw GlobalError.validation(
                        chineseMessage: "保存认证凭据失败",
                        i18nKey: "error.validation.credential_save_failed",
                        level: .notification
                    )
                }
            }

            Logger.shared.debug("已添加新玩家: \(name)")
        } catch {
            throw GlobalError.player(
                chineseMessage: "玩家创建失败: \(error.localizedDescription)",
                i18nKey: "error.player.creation_failed",
                level: .notification
            )
        }
    }

    /// 添加新玩家（静默版本）
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID，如果为nil则生成离线UUID
    ///   - isOnline: 是否为在线账户
    ///   - avatarName: 头像名称
    ///   - accToken: 访问令牌，默认为空字符串
    ///   - refreshToken: 刷新令牌，默认为空字符串
    ///   - xuid: Xbox用户ID，默认为空字符串
    ///   - expiresAt: 令牌过期时间，可选
    /// - Returns: 是否成功添加
    func addPlayerSilently(
        name: String,
        uuid: String? = nil,
        isOnline: Bool,
        avatarName: String,
        accToken: String = "",
        refreshToken: String = "",
        xuid: String = "",
        expiresAt: Date? = nil
    ) -> Bool {
        do {
            try addPlayer(
                name: name,
                uuid: uuid,
                isOnline: isOnline,
                avatarName: avatarName,
                accToken: accToken,
                refreshToken: refreshToken,
                xuid: xuid,
                expiresAt: expiresAt
            )
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 加载所有保存的玩家（静默版本）
    /// - Returns: 玩家数组
    func loadPlayers() -> [Player] {
        do {
            return try loadPlayersThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("加载玩家数据失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }

    /// 加载所有保存的玩家（抛出异常版本）
    /// - Returns: 玩家数组
    /// - Throws: GlobalError 当操作失败时
    func loadPlayersThrowing() throws -> [Player] {
        // 从 UserProfileStore 加载所有 profiles
        let profiles = try profileStore.loadProfilesThrowing()

        // 为每个 profile 加载对应的 credential（如果存在）
        var players: [Player] = []
        for profile in profiles {
            let credential = credentialStore.loadCredential(userId: profile.id)
            let player = Player(profile: profile, credential: credential)
            players.append(player)
        }

        return players
    }

    /// 检查玩家是否存在（不区分大小写）
    /// - Parameter name: 要检查的名称
    /// - Returns: 如果存在同名玩家则返回 true，否则返回 false
    func playerExists(name: String) -> Bool {
        do {
            let players = try loadPlayersThrowing()
            return players.contains { $0.name.lowercased() == name.lowercased() }
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查玩家存在性失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 删除指定ID的玩家
    /// - Parameter id: 要删除的玩家ID
    /// - Throws: GlobalError 当操作失败时
    func deletePlayer(byID id: String) throws {
        let players = try loadPlayersThrowing()
        let initialCount = players.count

        // 检查要删除的玩家是否为当前玩家
        let isDeletingCurrentPlayer = players.contains { $0.id == id && $0.isCurrent }

        // 删除 profile
        try profileStore.deleteProfile(byID: id)

        // 删除 credential（如果存在）
        _ = credentialStore.deleteCredential(userId: id)

        if initialCount > 0 {
            // 如果删除的是当前玩家，需要设置新的当前玩家
            if isDeletingCurrentPlayer {
                let remainingPlayers = try loadPlayersThrowing()
                if !remainingPlayers.isEmpty {
                    var firstPlayer = remainingPlayers[0]
                    firstPlayer.isCurrent = true
                    try updatePlayer(firstPlayer)
                    Logger.shared.debug("当前玩家被删除，已设置第一个玩家为当前玩家: \(firstPlayer.name)")
                }
            }
            Logger.shared.debug("已删除玩家 (ID: \(id))")
        }
    }

    /// 删除指定ID的玩家（静默版本）
    /// - Parameter id: 要删除的玩家ID
    /// - Returns: 是否成功删除
    func deletePlayerSilently(byID id: String) -> Bool {
        do {
            try deletePlayer(byID: id)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("删除玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 保存玩家数组（静默版本）
    /// - Parameter players: 要保存的玩家数组
    func savePlayers(_ players: [Player]) {
        do {
            try savePlayersThrowing(players)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("保存玩家数据失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 保存玩家数组（抛出异常版本）
    /// - Parameter players: 要保存的玩家数组
    /// - Throws: GlobalError 当操作失败时
    func savePlayersThrowing(_ players: [Player]) throws {
        // 分离 profiles 和 credentials
        var profiles: [UserProfile] = []
        var credentials: [AuthCredential] = []

        for player in players {
            profiles.append(player.profile)
            if let credential = player.credential {
                credentials.append(credential)
            }
        }

        // 保存 profiles
        try profileStore.saveProfilesThrowing(profiles)

        // 保存 credentials
        for credential in credentials where !credentialStore.saveCredential(credential) {
            throw GlobalError.validation(
                chineseMessage: "保存认证凭据失败: \(credential.userId)",
                i18nKey: "error.validation.credential_save_failed",
                level: .notification
            )
        }

        // 清理已删除玩家的 credentials
        let existingProfileIds = Set(profiles.map { $0.id })
        let allCredentials = try loadPlayersThrowing().compactMap { $0.credential }
        for credential in allCredentials where !existingProfileIds.contains(credential.userId) {
            _ = credentialStore.deleteCredential(userId: credential.userId)
        }

        Logger.shared.debug("玩家数据已保存")
    }

    /// 更新指定玩家的信息
    /// - Parameter updatedPlayer: 更新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func updatePlayer(_ updatedPlayer: Player) throws {
        // 更新 profile
        try profileStore.updateProfile(updatedPlayer.profile)

        // 更新或删除 credential
        if let credential = updatedPlayer.credential {
            if !credentialStore.saveCredential(credential) {
                throw GlobalError.validation(
                    chineseMessage: "更新认证凭据失败",
                    i18nKey: "error.validation.credential_update_failed",
                    level: .notification
                )
            }
        } else {
            // 如果 credential 为 nil，删除 Keychain 中的数据
            _ = credentialStore.deleteCredential(userId: updatedPlayer.id)
        }

        Logger.shared.debug("已更新玩家信息: \(updatedPlayer.name)")
    }

    /// 更新指定玩家的信息（静默版本）
    /// - Parameter updatedPlayer: 更新后的玩家对象
    /// - Returns: 是否成功更新
    func updatePlayerSilently(_ updatedPlayer: Player) -> Bool {
        do {
            try updatePlayer(updatedPlayer)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("更新玩家信息失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }
}
