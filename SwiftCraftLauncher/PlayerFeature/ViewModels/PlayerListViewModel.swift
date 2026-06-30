//
//  PlayerListViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages the player list and coordinates with ``PlayerDataManager`` for persistence.
class PlayerListViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var currentPlayer: Player?

    private let dataManager: PlayerDataManager
    private let errorHandler: GlobalErrorHandler
    private var notificationObserver: NSObjectProtocol?
    private var hasLoadedPlayers = false

    init(
        dataManager: PlayerDataManager = AppServices.playerDataManager,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.dataManager = dataManager
        self.errorHandler = errorHandler
        setupNotifications()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotifications() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .playerUpdated,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            if let updatedPlayer = notification.userInfo?["updatedPlayer"] as? Player {
                self?.updatePlayerInList(updatedPlayer)
            }
        }
    }

    /// Loads the player list on first invocation; subsequent calls are ignored.
    func loadPlayersIfNeeded() {
        guard !hasLoadedPlayers else { return }
        loadPlayersSafely()
    }

    /// Loads the player list, returning an empty list on failure.
    func loadPlayers() {
        loadPlayersSafely()
    }

    /// Loads the player list, throwing on failure.
    ///
    /// - Throws: A `GlobalError` if loading fails.
    func loadPlayersThrowing() throws {
        players = try dataManager.loadPlayersThrowing()
        currentPlayer = players.first { $0.isCurrent }
        Logger.shared.debug("玩家列表已加载，数量: \(players.count)")
        Logger.shared.debug("当前玩家 (加载后): \(currentPlayer?.name ?? "无")")
    }

    private func loadPlayersSafely() {
        do {
            try loadPlayersThrowing()
            hasLoadedPlayers = true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("加载玩家列表失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Adds an offline player with the given name.
    ///
    /// - Parameter name: The player's display name.
    /// - Returns: `true` if the player was added successfully.
    func addPlayer(name: String) -> Bool {
        do {
            try addPlayerThrowing(name: name)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加玩家失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// Adds an offline player with the given name, throwing on failure.
    ///
    /// - Parameter name: The player's display name.
    /// - Throws: A `GlobalError` if adding the player fails.
    func addPlayerThrowing(name: String) throws {
        try dataManager.addPlayer(name: name, isOnline: false, avatarName: "")
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 \(name) 添加成功，列表已更新。")
        Logger.shared.debug("当前玩家 (添加后): \(currentPlayer?.name ?? "无")")
    }

    /// Adds an online (Minecraft) player from a profile response.
    ///
    /// - Parameter profile: The Minecraft profile response.
    /// - Returns: `true` if the player was added successfully.
    func addOnlinePlayer(profile: MinecraftProfileResponse) -> Bool {
        do {
            try addOnlinePlayerThrowing(profile: profile)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加在线玩家失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// Adds an online (Minecraft) player from a profile response, throwing on failure.
    ///
    /// - Parameter profile: The Minecraft profile response.
    /// - Throws: A `GlobalError` if adding the player fails.
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
            xuid: profile.authXuid,
        )
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 \(profile.name) 添加成功，列表已更新。")
        Logger.shared.debug("当前玩家 (添加后): \(currentPlayer?.name ?? "无")")
    }

    /// Adds a Yggdrasil-authenticated player from a profile.
    ///
    /// - Parameter profile: The Yggdrasil player profile.
    /// - Returns: `true` if the player was added successfully.
    func addOnlinePlayer(profile: YggdrasilProfile) -> Bool {
        do {
            try addOnlinePlayerThrowing(profile: profile)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("添加 Yggdrasil 玩家失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// Adds a Yggdrasil-authenticated player from a profile, throwing on failure.
    ///
    /// - Parameter profile: The Yggdrasil player profile.
    /// - Throws: A `GlobalError` if adding the player fails.
    func addOnlinePlayerThrowing(profile: YggdrasilProfile) throws {
        let avatarUrl = profile.skins.isEmpty ? "" : profile.skins[0].url.httpToHttps()
        try dataManager.addPlayer(
            name: profile.name,
            uuid: profile.id,
            isOnline: false,
            avatarName: avatarUrl,
            accToken: profile.accessToken,
            refreshToken: profile.refreshToken,
            xuid: "",
        )
        try loadPlayersThrowing()
        Logger.shared.debug("Yggdrasil 玩家 \(profile.name) 添加成功，列表已更新。")
    }

    /// Deletes a player by identifier.
    ///
    /// - Parameter id: The identifier of the player to delete.
    /// - Returns: `true` if the player was deleted successfully.
    func deletePlayer(byID id: String) -> Bool {
        do {
            try deletePlayerThrowing(byID: id)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("删除玩家失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// Deletes a player by identifier, throwing on failure.
    ///
    /// - Parameter id: The identifier of the player to delete.
    /// - Throws: A `GlobalError` if deletion fails.
    func deletePlayerThrowing(byID id: String) throws {
        try dataManager.deletePlayer(byID: id)
        try loadPlayersThrowing()
        Logger.shared.debug("玩家 (ID: \(id)) 删除成功，列表已更新。")
        Logger.shared.debug("当前玩家 (删除后): \(currentPlayer?.name ?? "无")")
    }

    /// Sets the current player by identifier, without propagating errors.
    ///
    /// - Parameter playerId: The identifier of the player to set as current.
    func setCurrentPlayer(byID playerId: String) {
        if playerId != currentPlayer?.id {
            do {
                try setCurrentPlayerThrowing(byID: playerId)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("设置当前玩家失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
            }
        }
    }

    /// Sets the current player by identifier, throwing on failure.
    ///
    /// - Parameter playerId: The identifier of the player to set as current.
    /// - Throws: A `GlobalError` if the player is not found.
    func setCurrentPlayerThrowing(byID playerId: String) throws {
        guard let index = players.firstIndex(where: { $0.id == playerId })
        else {
            throw GlobalError.player(
                chineseMessage: "玩家不存在: \(playerId)",
                i18nKey: "error.player.not_found",
                level: .notification,
            )
        }

        for i in 0 ..< players.count {
            players[i].isCurrent = (i == index)
        }
        currentPlayer = players[index]

        try dataManager.savePlayersThrowing(players)
        Logger.shared.debug(
            "已设置玩家 (ID: \(playerId), 姓名: \(currentPlayer?.name ?? "未知")) 为当前玩家，数据已保存。",
        )
    }

    /// Checks whether a player with the given name already exists.
    ///
    /// - Parameter name: The name to check.
    /// - Returns: `true` if a matching player exists.
    func playerExists(name: String) -> Bool {
        dataManager.playerExists(name: name)
    }

    /// Updates a player in the local list from an external update notification.
    ///
    /// - Parameter updatedPlayer: The player with updated values.
    func updatePlayerInList(_ updatedPlayer: Player) {
        do {
            try updatePlayerInListThrowing(updatedPlayer)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("更新玩家列表失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
        }
    }

    /// Updates a player in the local list, throwing on failure.
    ///
    /// - Parameter updatedPlayer: The player with updated values.
    /// - Throws: A `GlobalError` if the update fails.
    func updatePlayerInListThrowing(_ updatedPlayer: Player) throws {
        Logger.shared.info("[updatePlayerInListThrowing] 更新前当前玩家信息:")
        if let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) {
            players[index] = updatedPlayer

            if let currentPlayer, currentPlayer.id == updatedPlayer.id {
                self.currentPlayer = updatedPlayer
            }

            Logger.shared.debug("玩家列表中的玩家信息已更新: \(updatedPlayer.name)")
        }
    }
}
