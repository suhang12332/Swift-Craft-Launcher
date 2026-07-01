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
        AppLog.player.debug("Player list loaded, count: \(self.players.count)")
        AppLog.player.debug("Current player (after loading): \(self.currentPlayer?.name ?? "none")")
    }

    private func loadPlayersSafely() {
        do {
            try loadPlayersThrowing()
            hasLoadedPlayers = true
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.player.error("Failed to load player list: \(globalError.localizedDescription)")
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
            AppLog.player.error("Failed to add player: \(globalError.localizedDescription)")
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
        AppLog.player.debug("Player \(name) added successfully, list updated.")
        AppLog.player.debug("Current player (after adding): \(self.currentPlayer?.name ?? "none")")
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
            AppLog.player.error("Failed to add online player: \(globalError.localizedDescription)")
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
        AppLog.player.debug("Player \(profile.name) added successfully, list updated.")
        AppLog.player.debug("Current player (after adding): \(self.currentPlayer?.name ?? "none")")
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
            AppLog.player.error("Failed to add Yggdrasil player: \(globalError.localizedDescription)")
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
        AppLog.player.debug("Yggdrasil player \(profile.name) added successfully, list updated.")
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
            AppLog.player.error("Failed to delete player: \(globalError.localizedDescription)")
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
        AppLog.player.debug("Player (ID: \(id)) deleted successfully, list updated.")
        AppLog.player.debug("Current player (after deletion): \(self.currentPlayer?.name ?? "none")")
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
                AppLog.player.error("Failed to set current player: \(globalError.localizedDescription)")
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
                i18nKey: "error.player.not_found",
                level: .notification,
                message: "Player with ID \"\(playerId)\" not found in player list",
            )
        }

        for i in 0 ..< players.count {
            players[i].isCurrent = (i == index)
        }
        currentPlayer = players[index]

        try dataManager.savePlayersThrowing(players)
        AppLog.player.debug(
            "Set player (ID: \(playerId), name: \(self.currentPlayer?.name ?? "unknown")) as current player, data saved.",
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
            AppLog.player.error("Failed to update player list: \(globalError.localizedDescription)")
            errorHandler.handle(globalError)
        }
    }

    /// Updates a player in the local list, throwing on failure.
    ///
    /// - Parameter updatedPlayer: The player with updated values.
    /// - Throws: A `GlobalError` if the update fails.
    func updatePlayerInListThrowing(_ updatedPlayer: Player) throws {
        AppLog.player.info("[updatePlayerInListThrowing] Current player info before update:")
        if let index = players.firstIndex(where: { $0.id == updatedPlayer.id }) {
            players[index] = updatedPlayer

            if let currentPlayer, currentPlayer.id == updatedPlayer.id {
                self.currentPlayer = updatedPlayer
            }

            AppLog.player.debug("Player info updated in list: \(updatedPlayer.name)")
        }
    }
}
