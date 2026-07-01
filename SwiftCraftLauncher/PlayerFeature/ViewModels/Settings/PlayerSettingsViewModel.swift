//
//  PlayerSettingsViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation
import MinecraftFriendsKit

/// Manages player-related settings in the settings view.
@MainActor
final class PlayerSettingsViewModel: ObservableObject {
    @Published var isDownloadingAuthlibInjector: Bool = false
    @Published var authlibInjectorExists: Bool = false

    @Published private(set) var minecraftFriendAccountPreferences: MinecraftFriendsPreferencesPayload?
    @Published private(set) var isLoadingMinecraftFriendAccountPreferences = false
    @Published private(set) var isSavingMinecraftFriendAccountPreferences = false

    private let friendsService: MinecraftFriendsService
    private let authService: MinecraftAuthService
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init(
        friendsService: MinecraftFriendsService = AppServices.minecraftFriendsService,
        authService: MinecraftAuthService = AppServices.minecraftAuthService,
        dataManager: PlayerDataManager = AppServices.playerDataManager,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.friendsService = friendsService
        self.authService = authService
        sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: dataManager,
            errorHandler: errorHandler,
        )
    }

    /// Updates whether the authlib-injector JAR file exists on disk.
    func refreshAuthlibInjectorExists() {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName,
        )
        authlibInjectorExists = FileManager.default.fileExists(atPath: authlibInjectorJarURL.path)
    }

    /// Downloads the authlib-injector JAR file.
    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName,
        )

        do {
            let downloadURL = URLConfig.API.AuthlibInjector.download
            _ = try await DownloadManager.downloadFile(
                urlString: downloadURL.absoluteString,
                destinationURL: authlibInjectorJarURL,
                expectedSha1: nil,
            )
            authlibInjectorExists = true
        } catch {
            let globalError = GlobalError.download(
                i18nKey: "error.download.authlib_injector_failed",
                level: .notification,
            )
            sideEffects.handle(globalError)
        }
    }

    /// Resets the Minecraft friend account preferences state.
    func clearMinecraftFriendAccountPreferences() {
        minecraftFriendAccountPreferences = nil
        isLoadingMinecraftFriendAccountPreferences = false
        isSavingMinecraftFriendAccountPreferences = false
    }

    /// Loads the Minecraft friend account preferences for the current player.
    ///
    /// - Parameter currentPlayer: The currently selected player.
    func reloadMinecraftFriendAccountPreferences(currentPlayer: Player?) async {
        guard let player = currentPlayer, player.isOnlineAccount else {
            clearMinecraftFriendAccountPreferences()
            return
        }

        isLoadingMinecraftFriendAccountPreferences = true
        defer { isLoadingMinecraftFriendAccountPreferences = false }

        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: sideEffects.reportMissingAccessToken) else {
            minecraftFriendAccountPreferences = nil
            return
        }

        do {
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken,
            )
            NotificationCenter.default.post(name: .minecraftFriendsAccountPreferencesDidChange, object: nil)
        } catch {
            minecraftFriendAccountPreferences = nil
            sideEffects.reportGlobalError(error)
        }
    }

    /// Enables or disables the Minecraft friend list.
    func setMinecraftFriendListEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let invitesOn = minecraftFriendAccountPreferences?.acceptInvites == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: enabled,
            enableFriendInvites: invitesOn,
        )
    }

    /// Enables or disables Minecraft friend invite acceptance.
    func setMinecraftFriendAcceptInvitesEnabled(_ enabled: Bool, currentPlayer: Player?) async {
        let friendsOn = minecraftFriendAccountPreferences?.friends == .enabled
        await persistMinecraftFriendAccountPreferences(
            currentPlayer: currentPlayer,
            enableFriendlist: friendsOn,
            enableFriendInvites: enabled,
        )
    }

    private func persistMinecraftFriendAccountPreferences(
        currentPlayer: Player?,
        enableFriendlist: Bool,
        enableFriendInvites: Bool,
    ) async {
        guard let player = currentPlayer, player.isOnlineAccount else { return }
        guard let tokenPlayer = await preparedTokenPlayer(for: player, onMissingCredential: sideEffects.reportMissingAccessToken) else { return }

        isSavingMinecraftFriendAccountPreferences = true
        defer { isSavingMinecraftFriendAccountPreferences = false }

        do {
            try await friendsService.updateFriendSettings(
                accessToken: tokenPlayer.authAccessToken,
                enableFriendlist: enableFriendlist,
                enableFriendInvites: enableFriendInvites,
            )
            minecraftFriendAccountPreferences = try await friendsService.fetchFriendAccountPreferences(
                accessToken: tokenPlayer.authAccessToken,
            )
            NotificationCenter.default.post(name: .minecraftFriendsAccountPreferencesDidChange, object: nil)
        } catch {
            sideEffects.reportGlobalError(error)
            await reloadMinecraftFriendAccountPreferences(currentPlayer: currentPlayer)
        }
    }

    /// Ensures the player has a valid access token, refreshing it if necessary.
    private func preparedTokenPlayer(for player: Player, onMissingCredential: () -> Void) async -> Player? {
        var resolved = player
        sideEffects.loadCredentialFromDiskIfMissing(into: &resolved)
        guard !resolved.authAccessToken.isEmpty else {
            onMissingCredential()
            return nil
        }

        do {
            let tokenPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: resolved)
            if tokenPlayer.authAccessToken != resolved.authAccessToken {
                sideEffects.persistPlayerIfNeeded(tokenPlayer)
            }
            return tokenPlayer
        } catch {
            sideEffects.reportGlobalError(error)
            return nil
        }
    }
}
