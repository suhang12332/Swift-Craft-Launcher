import Foundation

/// Handles saving and loading player data using UserDefaults.
class PlayerDataManager {
    private let playersKey = "savedPlayers"

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
    ///   - tokenExpiresAt: Token过期时间，默认为nil
    /// - Throws: GlobalError 当操作失败时
    func addPlayer(name: String, uuid: String? = nil, isOnline: Bool, avatarName: String, accToken: String = "", refreshToken: String = "", xuid: String = "", tokenExpiresAt: Date? = nil) throws {
        var players = try loadPlayersThrowing()

        if playerExists(name: name) {
            throw GlobalError.player(
                chineseMessage: "玩家已存在: \(name)",
                i18nKey: "error.player.already_exists",
                level: .notification
            )
        }

        do {
            let newPlayer = try Player(
                name: name,
                uuid: uuid,
                isOnlineAccount: isOnline,
                avatarName: avatarName,
                authXuid: xuid,
                authAccessToken: accToken,
                authRefreshToken: refreshToken,
                tokenExpiresAt: tokenExpiresAt,
                isCurrent: players.isEmpty
            )
            players.append(newPlayer)
            try savePlayersThrowing(players)
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
    ///   - tokenExpiresAt: Token过期时间，默认为nil
    /// - Returns: 是否成功添加
    func addPlayerSilently(name: String, uuid: String? = nil, isOnline: Bool, avatarName: String, accToken: String = "", refreshToken: String = "", xuid: String = "", tokenExpiresAt: Date? = nil) -> Bool {
        do {
            try addPlayer(name: name, uuid: uuid, isOnline: isOnline, avatarName: avatarName, accToken: accToken, refreshToken: refreshToken, xuid: xuid, tokenExpiresAt: tokenExpiresAt)
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
        guard let playersData = UserDefaults.standard.data(forKey: playersKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Player].self, from: playersData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "加载玩家数据失败: \(error.localizedDescription)",
                i18nKey: "error.validation.player_data_load_failed",
                level: .notification
            )
        }
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
        var players = try loadPlayersThrowing()
        let initialCount = players.count

        // 检查要删除的玩家是否为当前玩家
        let isDeletingCurrentPlayer = players.contains { $0.id == id && $0.isCurrent }

        players.removeAll { $0.id == id }

        if players.count < initialCount {
            // 如果删除的是当前玩家，需要设置新的当前玩家
            if isDeletingCurrentPlayer && !players.isEmpty {
                players[0].isCurrent = true
                Logger.shared.debug("当前玩家被删除，已设置第一个玩家为当前玩家: \(players[0].name)")
            }

            try savePlayersThrowing(players)
            Logger.shared.debug("已删除玩家 (ID: \(id))")
        } else {
            throw GlobalError.player(
                chineseMessage: "玩家不存在: \(id)",
                i18nKey: "error.player.not_found",
                level: .notification
            )
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
        do {
            let encoder = JSONEncoder()
            let encodedData = try encoder.encode(players)
            UserDefaults.standard.set(encodedData, forKey: playersKey)
            Logger.shared.debug("玩家数据已保存")
        } catch {
            throw GlobalError.validation(
                chineseMessage: "保存玩家数据失败: \(error.localizedDescription)",
                i18nKey: "error.validation.player_data_save_failed",
                level: .notification
            )
        }
    }

    /// 更新指定玩家的信息
    /// - Parameter updatedPlayer: 更新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func updatePlayer(_ updatedPlayer: Player) throws {
        var players = try loadPlayersThrowing()

        guard let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) else {
            throw GlobalError.player(
                chineseMessage: "要更新的玩家不存在: \(updatedPlayer.name)",
                i18nKey: "error.player.not_found_for_update",
                level: .notification
            )
        }

        players[index] = updatedPlayer
        try savePlayersThrowing(players)
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
