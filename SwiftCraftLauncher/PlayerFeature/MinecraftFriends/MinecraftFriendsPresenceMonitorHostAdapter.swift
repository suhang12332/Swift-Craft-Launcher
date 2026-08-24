//
//  MinecraftFriendsPresenceMonitorHostAdapter.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit

/// Adapts the app's player and authentication layer to the `MinecraftFriendsPresenceMonitorHost` protocol.
///
/// This adapter resolves Minecraft access tokens for the bound player and
/// delivers silent notifications for presence events.
@MainActor
final class MinecraftFriendsPresenceMonitorHostAdapter: MinecraftFriendsPresenceMonitorHost {
    private var player: Player?
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init(
        player: Player? = nil,
    ) {
        self.player = player
        sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: DIContainer.shared.ui.playerDataManager,
        )
    }

    /// Sets the player to use for access token resolution.
    ///
    /// - Parameter player: The player to bind, or `nil` to clear the binding.
    func setBoundPlayer(_ player: Player?) {
        self.player = player
    }

    /// Resolves a valid Minecraft access token for the requested player.
    ///
    /// The token is obtained by loading the credential from disk, refreshing it
    /// if necessary, and persisting any updated token back to the data manager.
    ///
    /// - Parameter playerId: The identifier of the player requesting the token.
    /// - Returns: The access token, or `nil` if resolution fails.
    func friendsAccessToken(playerId: String) async -> String? {
        await MinecraftFriendsHostMicrosoftAccessToken.resolve(
            requestedPlayerId: playerId,
            boundPlayerId: { self.player?.id ?? "" },
            copyBoundPlayer: { self.player },
            mergeCredentialFromDiskIfNeeded: { p in
                self.sideEffects.loadCredentialFromDiskIfMissing(into: &p)
            },
            minecraftAccessToken: { $0.authAccessToken },
            refreshPlayerToken: { try await DIContainer.shared.system.minecraftAuthService.validateAndRefreshPlayerTokenThrowing(for: $0) },
            persistIfMinecraftAccessTokenChanged: { _, after in
                self.sideEffects.persistPlayerIfNeeded(after)
            },
            applyRefreshedPlayer: { self.player = $0 },
            onMissingMinecraftAccessToken: { self.sideEffects.reportMissingAccessToken() },
            onRefreshFailure: { self.sideEffects.reportGlobalError($0) },
        )
    }

    /// Sends a silent local notification with the given title and body.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    func sendSilentNotification(title: String, body: String) async {
        do {
            try await NotificationManager.send(title: title, body: body)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to send notification: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }
}
