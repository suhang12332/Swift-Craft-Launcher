//
//  PlayerSettingsViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit
import Observation

/// Manages player-related settings in the settings view.
@MainActor
@Observable
final class PlayerSettingsViewModel {
    var isDownloadingAuthlibInjector: Bool = false
    var authlibInjectorExists: Bool = false

    private(set) var minecraftFriendAccountPreferences: MinecraftFriendsPreferencesPayload?
    private(set) var isLoadingMinecraftFriendAccountPreferences = false
    private(set) var isSavingMinecraftFriendAccountPreferences = false

    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init() {
        sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: DIContainer.shared.ui.playerDataManager,
            source: .settings,
        )
    }

    /// Updates whether the authlib-injector JAR file exists on disk.
    func refreshAuthlibInjectorExists() {
        authlibInjectorExists = FileManager.default.fileExists(atPath: AppConstants.AuthlibInjector.jarPath)
    }

    /// Fetches the latest authlib-injector version info from GitHub.
    /// - Returns: A tuple of (version, downloadURL), or nil if the request fails.
    private func fetchLatestAuthlibInjectorVersion() async -> (version: String, downloadURL: URL)? {
        guard let data = try? await APIClient.get(url: URLConfig.API.AuthlibInjector.latestRelease),
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            return nil
        }
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        let downloadURL = URLConfig.API.AuthlibInjector.downloadURL(version)
        return (version, downloadURL)
    }

    /// Downloads the latest authlib-injector JAR from GitHub releases.
    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        do {
            guard let latest = await fetchLatestAuthlibInjectorVersion() else {
                throw GlobalError.download(
                    i18nKey: "error.download.authlib_injector_failed",
                    level: .notification,
                )
            }

            let authDir = AppPaths.authDirectory

            // Remove all existing files in the auth directory
            if let files = try? FileManager.default.contentsOfDirectory(atPath: authDir.path) {
                for file in files {
                    try? FileManager.default.removeItem(at: authDir.appendingPathComponent(file))
                }
            }

            let destinationURL = authDir.appendingPathComponent(latest.downloadURL.lastPathComponent)

            _ = try await DownloadManager.downloadFile(
                urlString: latest.downloadURL.absoluteString,
                destinationURL: destinationURL,
                expectedSha1: nil,
            )

            authlibInjectorExists = true
            Defaults.save(latest.version, forKey: AppConstants.UserDefaultsKeys.authlibInjectorVersion)
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
            minecraftFriendAccountPreferences = try await DIContainer.shared.ui.minecraftFriendsService.fetchFriendAccountPreferences(
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
            try await DIContainer.shared.ui.minecraftFriendsService.updateFriendSettings(
                accessToken: tokenPlayer.authAccessToken,
                enableFriendlist: enableFriendlist,
                enableFriendInvites: enableFriendInvites,
            )
            minecraftFriendAccountPreferences = try await DIContainer.shared.ui.minecraftFriendsService.fetchFriendAccountPreferences(
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
            let tokenPlayer = try await DIContainer.shared.system.minecraftAuthService.validateAndRefreshPlayerTokenThrowing(for: resolved)
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
