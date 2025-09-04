import Foundation
import SwiftUI

/// A view model that manages the list of players and interacts with PlayerDataManager.
class PlayerListViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentPlayer: Player?

    private let dataManager = PlayerDataManager()
    private var notificationObserver: NSObjectProtocol?

    init() {
        loadPlayersSafely()
        setupNotifications()
    }
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    private func setupNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: PlayerSkinService.playerUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let updatedPlayer = notification.userInfo?["updatedPlayer"] as? Player {
                Logger.shared.info("🔔 [setupNotifications] 收到玩家更新通知:")
                Logger.shared.info("  - 姓名: \(updatedPlayer.name)")
                Logger.shared.info("  - 皮肤URL: \(updatedPlayer.avatarName)")
                Logger.shared.info("  - 是否当前玩家: \(updatedPlayer.isCurrent)")
                self?.updatePlayerInList(updatedPlayer)
            }
        }
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
        currentPlayer = players.first { $0.isCurrent }
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

    /// 更新玩家列表中的指定玩家信息
    /// - Parameter updatedPlayer: 更新后的玩家对象
    func updatePlayerInList(_ updatedPlayer: Player) {
        do {
            try updatePlayerInListThrowing(updatedPlayer)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("更新玩家列表失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    /// 更新玩家列表中的指定玩家信息（抛出异常版本）
    /// - Parameter updatedPlayer: 更新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func updatePlayerInListThrowing(_ updatedPlayer: Player) throws {
        // 记录更新前的当前玩家信息
        Logger.shared.info("📱 [updatePlayerInListThrowing] 更新前当前玩家信息:")
        if let currentPlayer = currentPlayer {
            Logger.shared.info("  - 姓名: \(currentPlayer.name)")
            Logger.shared.info("  - 皮肤URL: \(currentPlayer.avatarName)")
            Logger.shared.info("  - 是否当前玩家: \(currentPlayer.isCurrent)")
        } else {
            Logger.shared.info("  - 当前玩家: 无")
        }
        // 注意：数据管理器已在 PlayerSkinService 中更新，这里只更新内存中的状态

        // 更新本地玩家列表
        if let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) {
            players[index] = updatedPlayer

            // 如果更新的是当前玩家，也要更新 currentPlayer
            if let currentPlayer = currentPlayer, currentPlayer.id == updatedPlayer.id {
                self.currentPlayer = updatedPlayer
                Logger.shared.info("📱 [updatePlayerInListThrowing] 当前玩家信息已更新:")
                Logger.shared.info("  - 姓名: \(updatedPlayer.name)")
                Logger.shared.info("  - 皮肤URL: \(updatedPlayer.avatarName)")
                Logger.shared.info("  - 是否当前玩家: \(updatedPlayer.isCurrent)")
            }

            Logger.shared.debug("玩家列表中的玩家信息已更新: \(updatedPlayer.name)")
        }
    }
}
