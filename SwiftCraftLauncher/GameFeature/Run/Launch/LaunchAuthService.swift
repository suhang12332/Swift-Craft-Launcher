//
//  LaunchAuthService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The authenticated player data required to build a launch command.
struct LaunchCredentials {
    let player: Player
    let accessToken: String
    let authlibAgentArgument: String?
}

/// The result of validating a player before launch.
struct LaunchPlayerValidation {
    let player: Player
    let nonFatalErrors: [Error]
}

/// Refreshes authentication and resolves third-party credentials before launch.
@MainActor
struct LaunchAuthService {
    /// Refreshes the player's token and returns any non-fatal persistence errors.
    func validatePlayer(_ player: Player) async throws -> LaunchPlayerValidation {
        if let profile = OfflineUserServerMap.serverKey(for: player.id),
           let server = YggdrasilServerPresets.server(for: profile.serverBaseURL) {
            await DIContainer.shared.system.yggdrasilAuthService.refreshThirdPartyToken(
                profile: profile,
                server: server,
            )
        }

        guard player.isOnlineAccount else {
            return LaunchPlayerValidation(player: player, nonFatalErrors: [])
        }

        AppLog.game.info("Verifying player \(player.name) token before launch")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = DIContainer.shared.ui.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer = try await DIContainer.shared.system.minecraftAuthService
            .validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

        var nonFatalErrors: [Error] = []
        if validatedPlayer.authAccessToken != player.authAccessToken {
            AppLog.game.info("Player \(player.name) token updated, saved to data manager")
            if let error = persistPlayer(validatedPlayer) {
                nonFatalErrors.append(error)
            }
        }

        return LaunchPlayerValidation(player: validatedPlayer, nonFatalErrors: nonFatalErrors)
    }

    /// Resolves the access token and authlib-injector argument for a validated player.
    func makeCredentials(for player: Player) async throws -> LaunchCredentials {
        guard let profile = OfflineUserServerMap.serverKey(for: player.id) else {
            return LaunchCredentials(
                player: player,
                accessToken: player.authAccessToken,
                authlibAgentArgument: nil,
            )
        }

        let accessToken = try await getThirdPartyMcToken(player: player, profile: profile)
        switch try await resolveAuthlib(profile) {
        case let .useAgent(agentArgument):
            return LaunchCredentials(
                player: player,
                accessToken: accessToken,
                authlibAgentArgument: agentArgument,
            )
        case .continueWithoutInjector:
            return LaunchCredentials(
                player: player,
                accessToken: player.authAccessToken,
                authlibAgentArgument: nil,
            )
        }
    }

    private func persistPlayer(_ player: Player) -> Error? {
        let dataManager = DIContainer.shared.ui.playerDataManager
        do {
            try dataManager.updatePlayer(player)
            AppLog.game.debug("Updated token info in player data manager")
            NotificationCenter.default.post(
                name: .playerUpdated,
                object: nil,
                userInfo: ["updatedPlayer": player],
            )
            return nil
        } catch {
            AppLog.game.error("Failed to save updated token: \(error.localizedDescription)")
            return error
        }
    }

    private func getThirdPartyMcToken(player: Player, profile: YggdrasilProfile) async throws -> String {
        guard let server = YggdrasilServerPresets.server(for: profile.serverBaseURL) else {
            return player.authAccessToken
        }

        do {
            return try await DIContainer.shared.system.yggdrasilAuthService.getMinecraftToken(
                profile: profile,
                server: server,
            )
        } catch {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
                message: "Failed to fetch Minecraft token for profile=\(profile.serverBaseURL): \(error.localizedDescription)",
            )
        }
    }

    private enum AuthlibResolution {
        case useAgent(String)
        case continueWithoutInjector
    }

    private func resolveAuthlib(_ profile: YggdrasilProfile) async throws -> AuthlibResolution {
        let jarPath = AppConstants.AuthlibInjector.jarPath
        if !FileManager.default.fileExists(atPath: jarPath) {
            AppLog.game.error("Authlib Injector JAR does not exist, waiting for user selection: \(jarPath)")
            let choice = await DIContainer.shared.ui.authlibInjectorMissingPresenter.requestUserChoice()
            switch choice {
            case .continueWithoutInjector:
                return .continueWithoutInjector
            case .cancel:
                throw AuthlibInjectorLaunchCancelled()
            }
        }

        let serverApiRoot = URLConfig.API.AuthlibInjector.serverApiRoot(for: profile.serverBaseURL)
        return .useAgent(AppConstants.AuthlibInjector.agentArgument(serverApiRoot: serverApiRoot))
    }
}
