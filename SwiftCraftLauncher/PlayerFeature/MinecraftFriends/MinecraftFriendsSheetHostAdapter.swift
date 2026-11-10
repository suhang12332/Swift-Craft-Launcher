//
//  MinecraftFriendsSheetHostAdapter.swift
//  PlayerFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import MinecraftFriendsKit

/// Adapts the app's player and authentication layer to the `MinecraftFriendsSheetHost` protocol.
///
/// This adapter resolves Minecraft access tokens, reports errors, and provides
/// skin texture URLs for the friends sheet UI.
@MainActor
final class MinecraftFriendsSheetHostAdapter: MinecraftFriendsSheetHost {
    private var player: Player
    private let sideEffects: MinecraftFriendsMicrosoftPlayerSideEffects

    init(
        player: Player,
    ) {
        self.player = player
        sideEffects = MinecraftFriendsMicrosoftPlayerSideEffects(
            dataManager: DIContainer.shared.ui.playerDataManager,
        )
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
            boundPlayerId: { self.player.id },
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

    /// Reports a friends-related error to the error handler.
    ///
    /// - Parameter error: The error to report.
    func reportFriendsError(_ error: Error) {
        sideEffects.reportGlobalError(error)
    }

    /// Resolves the skin texture URL for the given player UUID.
    ///
    /// - Parameter uuidNoHyphens: The player's UUID without hyphens.
    /// - Returns: The skin texture URL, or `nil` if resolution fails.
    func skinTextureURL(uuidNoHyphens: String) async -> String? {
        await DIContainer.shared.ui.minecraftFriendsService.resolveSessionProfileSkinTextureURL(uuidNoHyphens: uuidNoHyphens)
    }
}
