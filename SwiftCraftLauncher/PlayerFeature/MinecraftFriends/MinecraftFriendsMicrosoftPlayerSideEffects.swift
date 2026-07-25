//
//  MinecraftFriendsMicrosoftPlayerSideEffects.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides side-effect operations for Microsoft Minecraft friends flows.
///
/// This type encapsulates disk credential loading, missing-token reporting,
/// silent player persistence, and error handling for the friends feature.
@MainActor
struct MinecraftFriendsMicrosoftPlayerSideEffects {
    let dataManager: PlayerDataManager
    let source: ErrorSource

    init(dataManager: PlayerDataManager, source: ErrorSource = .main) {
        self.dataManager = dataManager
        self.source = source
    }

    /// Loads a credential from disk into the given player if one is not already present.
    ///
    /// - Parameter player: The player to modify in place.
    func loadCredentialFromDiskIfMissing(into player: inout Player) {
        if player.credential == nil {
            player.credential = dataManager.loadCredential(userId: player.id)
        }
    }

    /// Reports a missing Minecraft access token to the error handler.
    func reportMissingAccessToken() {
        DIContainer.shared.core.errorHandler.handle(
            GlobalError.authentication(
                i18nKey: "error.authentication.missing_token",
                level: .notification,
                source: source,
            ),
        )
    }

    /// Persists the given player and posts a `playerUpdated` notification on success.
    ///
    /// - Parameter updated: The player to persist.
    func persistPlayerIfNeeded(_ updated: Player) {
        guard dataManager.updatePlayerSilently(updated) else { return }
        NotificationCenter.default.post(
            name: .playerUpdated,
            object: nil,
            userInfo: ["updatedPlayer": updated],
        )
    }

    /// Forwards an error to the error handler.
    ///
    /// - Parameter error: The error to report.
    func reportGlobalError(_ error: Error) {
        DIContainer.shared.core.errorHandler.handle(error, source: source)
    }

    /// Forwards a `GlobalError` to the error handler.
    ///
    /// - Parameter error: The error to report.
    func handle(_ error: GlobalError) {
        DIContainer.shared.core.errorHandler.handle(error.withSource(source))
    }
}
