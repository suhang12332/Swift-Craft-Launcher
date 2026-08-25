//
//  MinecraftAuthService+TokenRefresh.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Handles Minecraft token validation and refresh operations.
extension MinecraftAuthService {
    func validateAndRefreshPlayerTokenThrowing(for player: Player) async throws -> Player {
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.missing_token",
                level: .notification,
                message: "Access token is empty for player \(player.name)",
            )
        }

        let isTokenExpired = await isTokenExpiredBasedOnTime(for: player)

        if !isTokenExpired {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                AppLog.common.debug("Token for player \(player.name) not yet expired, no refresh needed")
            }
            return player
        }

        AppLog.common.info("Token for player \(player.name) expired, attempting refresh")

        guard !player.authRefreshToken.isEmpty else {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_expired_relogin_required",
                level: .popup,
                message: "Refresh token is empty for player \(player.name), re-login required",
            )
        }

        let (taskToAwait, didCreate): (Task<Player, Error>, Bool) = refreshTasksLock.withLock { tasks in
            if let existingTask = tasks[player.id] {
                return (existingTask, false)
            }
            let newTask = Task<Player, Error> { @MainActor [weak self] in
                guard let self else { throw CancellationError() }
                return try await doRefreshPlayerToken(for: player)
            }
            tasks[player.id] = newTask
            return (newTask, true)
        }

        if !didCreate {
            return try await taskToAwait.value
        }

        defer {
            _ = refreshTasksLock.withLock { tasks in
                tasks.removeValue(forKey: player.id)
            }
        }

        return try await taskToAwait.value
    }

    private func doRefreshPlayerToken(for player: Player) async throws -> Player {
        let refreshedTokens = try await refreshTokenThrowing(refreshToken: player.authRefreshToken)

        let xboxToken = try await getXboxLiveTokenThrowing(accessToken: refreshedTokens.accessToken)
        let minecraftToken = try await getMinecraftTokenThrowing(
            xboxToken: xboxToken.token,
            uhs: xboxToken.displayClaims.xui.first?.uhs ?? "",
        )

        var updatedProfile = player.profile
        updatedProfile.lastPlayed = player.lastPlayed
        updatedProfile.isCurrent = player.isCurrent

        var updatedCredential = player.credential
        if var credential = updatedCredential {
            credential.accessToken = minecraftToken
            credential.refreshToken = refreshedTokens.refreshToken ?? player.authRefreshToken
            credential.xuid = xboxToken.displayClaims.xui.first?.uhs ?? player.authXuid
            updatedCredential = credential
        } else {
            updatedCredential = AuthCredential(
                userId: player.id,
                accessToken: minecraftToken,
                refreshToken: refreshedTokens.refreshToken ?? "",
                xuid: xboxToken.displayClaims.xui.first?.uhs ?? "",
            )
        }

        return Player(profile: updatedProfile, credential: updatedCredential)
    }

    func refreshTokenThrowing(refreshToken: String) async throws -> TokenResponse {
        try await OAuth2TokenOperations.refreshToken(
            refreshToken: refreshToken,
            tokenURL: URLConfig.API.Authentication.token,
            clientId: clientId,
        )
    }

    func isTokenExpiredBasedOnTime(for player: Player) async -> Bool {
        JWTDecoder.isTokenExpiringSoon(player.authAccessToken)
    }
}
