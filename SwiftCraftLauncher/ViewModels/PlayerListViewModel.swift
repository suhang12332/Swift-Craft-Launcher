import Foundation
import SwiftUI

/// A view model that manages the list of players and interacts with PlayerDataManager.
class PlayerListViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentPlayer: Player? = nil

    private let dataManager = PlayerDataManager()

    init() {
        loadPlayersSafely()
    }

    // MARK: - Public Methods

    /// 加载玩家列表（静默版本）
    func loadPlayers() {
        loadPlayersSafely()
    }

    /// 加载玩家列表（抛出异常版本）
    /// - Throws: GlobalError 当操作失败时
    func loadPlayersThrowing() throws {
        players = try dataManager.loadPlayersThrowing()
        currentPlayer = players.first(where: { $0.isCurrent })
        Logger.shared.debug("玩家列表已加载，数量: \(players.count)")
        Logger.shared.debug("当前玩家 (加载后): \(currentPlayer?.name ?? "无")")
    }

    /// 安全地加载玩家列表
    private func loadPlayersSafely() {
        do {
            try loadPlayersThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("加载玩家列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            // 保持现有状态
        }
    }

    /// 添加新玩家（静默版本）
    /// - Parameter name: 要添加的玩家名称
    /// - Returns: 是否成功添加
    func addPlayer(name: String) -> Bool {
        do {
            try addPlayerThrowing(name: name)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 添加新玩家（抛出异常版本）
    /// - Parameter name: 要添加的玩家名称
    /// - Throws: GlobalError 当操作失败时
    func addPlayerThrowing(name: String) throws {
        try dataManager.addPlayer(name: name, isOnline: false, avatarName: "")
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 \(name) 添加成功，列表已更新。")
        Logger.shared.debug("当前玩家 (添加后): \(currentPlayer?.name ?? "无")")
    }

    /// 添加在线玩家（静默版本）
    /// - Parameter profile: Minecraft 配置文件
    /// - Returns: 是否成功添加
    func addOnlinePlayer(profile: MinecraftProfileResponse) -> Bool {
        do {
            try addOnlinePlayerThrowing(profile: profile)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加在线玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 添加在线玩家（抛出异常版本）
    /// - Parameter profile: Minecraft 配置文件
    /// - Throws: GlobalError 当操作失败时
    func addOnlinePlayerThrowing(profile: MinecraftProfileResponse) throws {
        let avatarUrl =
            profile.skins.isEmpty ? "" : profile.skins[0].url.httpToHttps()
        try dataManager.addPlayer(
            name: profile.name,
            uuid: profile.id,
            isOnline: true,
            avatarName: avatarUrl,
            accToken: profile.accessToken,
            refreshToken: profile.refreshToken,
            xuid: profile.authXuid
        )
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 \(profile.name) 添加成功，列表已更新。")
        Logger.shared.debug("当前玩家 (添加后): \(currentPlayer?.name ?? "无")")
    }

    /// 添加 Yggdrasil 玩家（静默版本）
    /// - Parameter profile: Yggdrasil 配置文件
    /// - Returns: 是否成功添加
    func addYggdrasilPlayer(profile: YggdrasilProfileResponse) -> Bool {
        // 从皮肤纹理中获取皮肤URL，如果有的话
        let avatarUrl = profile.textures?.textures.SKIN?.url ?? ""

        // 使用新的第三方账户添加方法，保留原有UUID和皮肤信息
        return addThirdPartyPlayer(
            name: profile.username,
            uuid: profile.id,
            avatarUrl: avatarUrl,
            accToken: profile.accessToken,
            refreshToken: profile.refreshToken ?? ""
        )
    }

    /// 添加 Yggdrasil 玩家（抛出异常版本）
    /// - Parameter profile: Yggdrasil 配置文件
    /// - Throws: GlobalError 当操作失败时
    func addYggdrasilPlayerThrowing(profile: YggdrasilProfileResponse) throws {
        // 从皮肤纹理中获取皮肤URL，如果有的话
        let avatarUrl = profile.textures?.textures.SKIN?.url ?? ""

        // 使用新的第三方账户添加方法，保留原有UUID和皮肤信息
        try addThirdPartyPlayerThrowing(
            name: profile.username,
            uuid: profile.id,
            avatarUrl: avatarUrl,
            accToken: profile.accessToken,
            refreshToken: profile.refreshToken ?? ""
        )
    }

    /// 添加第三方账户玩家（静默版本）
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID
    ///   - avatarUrl: 皮肤URL
    ///   - accToken: 访问令牌
    ///   - refreshToken: 刷新令牌
    /// - Returns: 是否成功添加
    func addThirdPartyPlayer(name: String, uuid: String, avatarUrl: String, accToken: String = "", refreshToken: String = "") -> Bool {
        do {
            try addThirdPartyPlayerThrowing(name: name, uuid: uuid, avatarUrl: avatarUrl, accToken: accToken, refreshToken: refreshToken)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加第三方账户玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 添加第三方账户玩家（抛出异常版本）
    /// - Parameters:
    ///   - name: 玩家名称
    ///   - uuid: 玩家UUID
    ///   - avatarUrl: 皮肤URL
    ///   - accToken: 访问令牌
    ///   - refreshToken: 刷新令牌
    /// - Throws: GlobalError 当操作失败时
    func addThirdPartyPlayerThrowing(name: String, uuid: String, avatarUrl: String, accToken: String = "", refreshToken: String = "") throws {
        try dataManager.addThirdPartyPlayer(
            name: name,
            uuid: uuid,
            avatarUrl: avatarUrl,
            accToken: accToken,
            refreshToken: refreshToken
        )
        try loadPlayersThrowing()
        Logger.shared.debug("第三方账户玩家 \(name) 添加成功，列表已更新。")
        Logger.shared.debug("当前玩家 (添加后): \(currentPlayer?.name ?? "无")")
    }

    /// 删除玩家（静默版本）
    /// - Parameter id: 要删除的玩家ID
    /// - Returns: 是否成功删除
    func deletePlayer(byID id: String) -> Bool {
        do {
            try deletePlayerThrowing(byID: id)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("删除玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// 删除玩家（抛出异常版本）
    /// - Parameter id: 要删除的玩家ID
    /// - Throws: GlobalError 当操作失败时
    func deletePlayerThrowing(byID id: String) throws {
        try dataManager.deletePlayer(byID: id)
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 (ID: \(id)) 删除成功，列表已更新。")
        Logger.shared.debug("当前玩家 (删除后): \(currentPlayer?.name ?? "无")")
    }

    /// 设置当前玩家（静默版本）
    /// - Parameter playerId: 要设置为当前玩家的ID
    func setCurrentPlayer(byID playerId: String) {
        do {
            try setCurrentPlayerThrowing(byID: playerId)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("设置当前玩家失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 设置当前玩家（抛出异常版本）
    /// - Parameter playerId: 要设置为当前玩家的ID
    /// - Throws: GlobalError 当操作失败时
    func setCurrentPlayerThrowing(byID playerId: String) throws {
        guard let index = players.firstIndex(where: { $0.id == playerId })
        else {
            throw GlobalError.player(
                chineseMessage: "玩家不存在: \(playerId)",
                i18nKey: "error.player.not_found",
                level: .notification
            )
        }

        for i in 0..<players.count {
            players[i].isCurrent = (i == index)
        }
        currentPlayer = players[index]

        try dataManager.savePlayersThrowing(players)
        Logger.shared.debug(
            "已设置玩家 (ID: \(playerId), 姓名: \(currentPlayer?.name ?? "未知")) 为当前玩家，数据已保存。"
        )
    }

    /// 检查玩家是否存在
    /// - Parameter name: 要检查的名称
    /// - Returns: 如果存在同名玩家则返回 true，否则返回 false
    func playerExists(name: String) -> Bool {
        dataManager.playerExists(name: name)
    }
}
