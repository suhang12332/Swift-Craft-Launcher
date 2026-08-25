//
//  ContentToolbarViewModel.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Provides preloaded skin and profile data for the content toolbar's skin manager.
@MainActor
@Observable
final class ContentToolbarViewModel {
    var isLoadingSkin: Bool = false
    var preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    var preloadedProfile: MinecraftProfileResponse?

    init() { }

    /// Preloads skin and profile data for the given player before opening the skin manager.
    ///
    /// For online accounts the method validates and refreshes the player token before fetching.
    /// - Parameter player: The player whose skin data should be loaded, or `nil` to skip.
    func preloadSkinDataForManager(player: Player?) async {
        guard let player else { return }

        isLoadingSkin = true
        defer { isLoadingSkin = false }

        if !player.isOnlineAccount {
            async let skinInfo = fetchSkinInfoSafely(player: player)
            async let profile = fetchPlayerProfileSafely(player: player)
            let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
            preloadedSkinInfo = loadedSkinInfo
            preloadedProfile = loadedProfile
            return
        }

        AppLog.main.info("Validating token for player \(player.name) before opening skin manager")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = DIContainer.shared.ui.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer: Player
        do {
            validatedPlayer = try await DIContainer.shared.system.minecraftAuthService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

            if validatedPlayer.authAccessToken != player.authAccessToken {
                AppLog.main.info("Token updated for player \(player.name), saving to data manager")
                let dataManager = DIContainer.shared.ui.playerDataManager
                do {
                    try dataManager.updatePlayer(validatedPlayer)
                    AppLog.main.debug("Token info updated in player data manager")
                    NotificationCenter.default.post(
                        name: .playerUpdated,
                        object: nil,
                        userInfo: ["updatedPlayer": validatedPlayer],
                    )
                } catch {
                    AppLog.main.error("Failed to save updated token: \(error.localizedDescription)")
                    DIContainer.shared.core.errorHandler.handle(error)
                }
            }
        } catch {
            AppLog.main.error("Failed to refresh token: \(error.localizedDescription)")
            validatedPlayer = playerWithCredential
        }

        async let skinInfo = fetchSkinInfoSafely(player: validatedPlayer)
        async let profile = fetchPlayerProfileSafely(player: validatedPlayer)
        let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
        preloadedSkinInfo = loadedSkinInfo
        preloadedProfile = loadedProfile
    }

    /// Clears any previously preloaded skin and profile data.
    func clearPreloadedSkinData() {
        preloadedSkinInfo = nil
        preloadedProfile = nil
    }

    private func fetchSkinInfoSafely(player: Player) async -> PlayerSkinService.PublicSkinInfo? {
        do {
            return try await PlayerSkinService.fetchCurrentPlayerSkinFromServicesThrowing(player: player)
        } catch {
            AppLog.player.error("Failed to fetch skin info from Minecraft Services API: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchPlayerProfileSafely(player: Player) async -> MinecraftProfileResponse? {
        do {
            return try await PlayerSkinService.fetchPlayerProfileThrowing(player: player)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.player.error("Fetch player profile failed: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return nil
        }
    }
}
