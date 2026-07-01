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
final class ContentToolbarViewModel: ObservableObject {
    @Published var isLoadingSkin: Bool = false
    @Published var preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    @Published var preloadedProfile: MinecraftProfileResponse?
    private let authService: MinecraftAuthService

    init(authService: MinecraftAuthService = AppServices.minecraftAuthService) {
        self.authService = authService
    }

    /// Preloads skin and profile data for the given player before opening the skin manager.
    ///
    /// For online accounts the method validates and refreshes the player token before fetching.
    /// - Parameter player: The player whose skin data should be loaded, or `nil` to skip.
    func preloadSkinDataForManager(player: Player?) async {
        guard let player else { return }

        isLoadingSkin = true
        defer { isLoadingSkin = false }

        if !player.isOnlineAccount {
            async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: player)
            async let profile = PlayerSkinService.fetchPlayerProfile(player: player)
            let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
            preloadedSkinInfo = loadedSkinInfo
            preloadedProfile = loadedProfile
            return
        }

        AppLog.main.info("Validating token for player \(player.name) before opening skin manager")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = AppServices.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer: Player
        do {
            validatedPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

            if validatedPlayer.authAccessToken != player.authAccessToken {
                AppLog.main.info("Token updated for player \(player.name), saving to data manager")
                let dataManager = AppServices.playerDataManager
                let success = dataManager.updatePlayerSilently(validatedPlayer)
                if success {
                    AppLog.main.debug("Token info updated in player data manager")
                    NotificationCenter.default.post(
                        name: .playerUpdated,
                        object: nil,
                        userInfo: ["updatedPlayer": validatedPlayer],
                    )
                }
            }
        } catch {
            AppLog.main.error("Failed to refresh token: \(error.localizedDescription)")
            validatedPlayer = playerWithCredential
        }

        async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: validatedPlayer)
        async let profile = PlayerSkinService.fetchPlayerProfile(player: validatedPlayer)
        let (loadedSkinInfo, loadedProfile) = await (skinInfo, profile)
        preloadedSkinInfo = loadedSkinInfo
        preloadedProfile = loadedProfile
    }

    /// Clears any previously preloaded skin and profile data.
    func clearPreloadedSkinData() {
        preloadedSkinInfo = nil
        preloadedProfile = nil
    }
}
