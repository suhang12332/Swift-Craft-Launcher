//
//  PlayerListViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import SwiftUI

/// Manages the player list and coordinates with ``PlayerDataManager`` for persistence.
@Observable
class PlayerListViewModel: @unchecked Sendable {
    var players: [Player] = []
    var currentPlayer: Player?

    private var notificationObserver: NSObjectProtocol?
    private var hasLoadedPlayers = false

    init() {
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

    /// Loads the player list, throwing on failure.
    ///
    /// - Throws: A `GlobalError` if loading fails.
    func loadPlayersThrowing() throws {
        players = try DIContainer.shared.ui.playerDataManager.loadPlayersThrowing()
        currentPlayer = players.first { $0.isCurrent }
        let count = players.count
        let playerName = currentPlayer?.name ?? "none"
        AppLog.player.debug("Player list loaded, count: \(count)")
        AppLog.player.debug("Current player (after loading): \(playerName)")
    }

    private func loadPlayersSafely() {
        do {
            try loadPlayersThrowing()
            hasLoadedPlayers = true
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.player.error("Failed to load player list: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    /// Adds an offline player with the given name, throwing on failure.
    ///
    /// - Parameter name: The player's display name.
    /// - Throws: A `GlobalError` if adding the player fails.
    func addPlayerThrowing(name: String) throws {
        try DIContainer.shared.ui.playerDataManager.addPlayer(name: name, isOnline: false, avatarName: "")
        try loadPlayersThrowing()
        AppLog.player.debug("Player \(name) added successfully, list updated.")
        let playerName = currentPlayer?.name ?? "none"
        AppLog.player.debug("Current player (after adding): \(playerName)")
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
            DIContainer.shared.core.errorHandler.handle(globalError)
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
        try DIContainer.shared.ui.playerDataManager.addPlayer(
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
        let playerName = currentPlayer?.name ?? "none"
        AppLog.player.debug("Current player (after adding): \(playerName)")
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
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }

    /// Adds a Yggdrasil-authenticated player from a profile, throwing on failure.
    ///
    /// Signing in again to a player that already belongs to the same server only
    /// refreshes its stored Yggdrasil profile (for example after the token expired or
    /// the password changed). Otherwise the player is added as before, and the server
    /// link is written only after the add succeeded, so a rejected add (such as an
    /// offline player with the same name and an offline-compatible UUID) never gets a
    /// server attached to it.
    ///
    /// - Parameter profile: The Yggdrasil player profile.
    /// - Throws: A `GlobalError` if adding the player fails.
    func addOnlinePlayerThrowing(profile: YggdrasilProfile) throws {
        let dataManager = DIContainer.shared.ui.playerDataManager
        let avatarUrl = profile.skins.isEmpty ? "" : profile.skins[0].url.httpToHttps()

        if OfflineUserServerMap.serverKey(for: profile.id)?.serverBaseURL == profile.serverBaseURL,
           var existing = try dataManager.loadPlayersThrowing().first(where: { $0.id == profile.id }) {
            OfflineUserServerMap.setServer(profile)
            if existing.name != profile.name || (!avatarUrl.isEmpty && existing.avatarName != avatarUrl) {
                existing.profile = UserProfile(
                    id: existing.profile.id,
                    name: profile.name,
                    avatar: avatarUrl.isEmpty ? existing.profile.avatar : avatarUrl,
                    lastPlayed: existing.profile.lastPlayed,
                    isCurrent: existing.profile.isCurrent,
                )
                try dataManager.updatePlayer(existing)
            }
            try loadPlayersThrowing()
            AppLog.player.debug("Yggdrasil player \(profile.name) signed in again, stored profile refreshed.")
            return
        }

        try dataManager.addPlayer(
            name: profile.name,
            uuid: profile.id,
            isOnline: false,
            avatarName: avatarUrl,
            accToken: profile.accessToken,
            refreshToken: profile.refreshToken,
            xuid: "",
        )
        OfflineUserServerMap.setServer(profile)
        try loadPlayersThrowing()
        AppLog.player.debug("Yggdrasil player \(profile.name) added successfully, list updated.")
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
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
        }
    }

    /// Deletes a player by identifier, throwing on failure.
    ///
    /// - Parameter id: The identifier of the player to delete.
    /// - Throws: A `GlobalError` if deletion fails.
    func deletePlayerThrowing(byID id: String) throws {
        try DIContainer.shared.ui.playerDataManager.deletePlayer(byID: id)
        try loadPlayersThrowing()
        AppLog.player.debug("Player (ID: \(id)) deleted successfully, list updated.")
        let playerName = currentPlayer?.name ?? "none"
        AppLog.player.debug("Current player (after deletion): \(playerName)")
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
            DIContainer.shared.core.errorHandler.handle(globalError)
            return false
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

        try DIContainer.shared.ui.playerDataManager.savePlayersThrowing(players)
        let playerName = currentPlayer?.name ?? "unknown"
        AppLog.player.debug(
            "Set player (ID: \(playerId), name: \(playerName)) as current player, data saved.",
        )
    }

    /// Sets the current player by identifier.
    ///
    /// - Parameter playerId: The identifier of the player to set as current.
    func setCurrentPlayer(byID playerId: String) {
        if playerId != currentPlayer?.id {
            do {
                try setCurrentPlayerThrowing(byID: playerId)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.player.error("Failed to set current player: \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
            }
        }
    }

    /// Checks whether a player with the given name already exists.
    ///
    /// - Parameter name: The name to check.
    /// - Returns: `true` if a matching player exists.
    func playerExists(name: String) -> Bool {
        (try? DIContainer.shared.ui.playerDataManager.playerExistsThrowing(name: name)) ?? false
    }

    /// Updates a player in the local list.
    ///
    /// - Parameter updatedPlayer: The player with updated values.
    func updatePlayerInList(_ updatedPlayer: Player) {
        do {
            try updatePlayerInListThrowing(updatedPlayer)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.player.error("Failed to update player in list: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
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
