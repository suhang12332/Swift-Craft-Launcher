//
//  MinecraftLaunchCommand.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AVFoundation
import Foundation

/// Orchestrates the Minecraft game launch process including authentication and process management.
struct MinecraftLaunchCommand {
    let player: Player
    let game: GameVersionInfo

    func launchGame() async {
        do {
            try await launchGameThrowing()
        } catch {
            await handleLaunchError(error)
        }
    }

    func stopGame() async {
        _ = DIContainer.shared.core.gameProcessManager.stopProcess(for: game.id, userId: player.id)
    }

    func launchGameThrowing() async throws {
        if let integrityError = GameIntegrityChecker.check(game: game) {
            throw integrityError
        }

        let validatedPlayer = try await validatePlayerTokenBeforeLaunch()

        if DIContainer.shared.ui.gameSettingsManager.enableMemoryPressureWarning {
            guard await checkMemoryPressure() else { return }
        }

        let command = game.launchCommand
        try await launchGameProcess(
            command: try await replaceAuthParameters(command: command, with: validatedPlayer),
        )
    }

    private func validatePlayerTokenBeforeLaunch() async throws -> Player {
        if let profile = OfflineUserServerMap.serverKey(for: player.id) {
            if profile.isPasswordLogin {
                return try await renewPasswordProfileBeforeLaunch(profile)
            }
            if let server = YggdrasilServerPresets.server(for: profile.serverBaseURL) {
                await DIContainer.shared.system.yggdrasilAuthService.refreshThirdPartyToken(
                    profile: profile,
                    server: server,
                )
            }
        }
        guard player.isOnlineAccount else {
            return player
        }

        AppLog.game.info("Verifying player \(player.name) token before launch")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = DIContainer.shared.ui.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer = try await DIContainer.shared.system.minecraftAuthService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

        if validatedPlayer.authAccessToken != player.authAccessToken {
            AppLog.game.info("Player \(player.name) token updated, saved to data manager")
            await updatePlayerInDataManager(validatedPlayer)
        }

        return validatedPlayer
    }

    /// Ensures a password-login player has a usable token before launching.
    ///
    /// Unlike OAuth presets, which keep the old token when refreshing fails, a password
    /// login that cannot be recovered aborts the launch with a clear error. The renewed
    /// profile is written back to ``OfflineUserServerMap``, and a rename on the server
    /// side is synced to the local player.
    private func renewPasswordProfileBeforeLaunch(_ profile: YggdrasilProfile) async throws -> Player {
        let renewed: YggdrasilProfile
        do {
            renewed = try await DIContainer.shared.system.yggdrasilAuthService.ensureFreshPasswordProfile(profile)
        } catch let YggdrasilAuthService.YggdrasilRenewalError.passwordRejected(clearedProfile) {
            OfflineUserServerMap.setServer(clearedProfile)
            throw GlobalError.authentication(
                i18nKey: "yggdrasil.error.password_changed",
                level: .popup,
                message: "Saved password rejected for user \(profile.id)",
            )
        }

        if renewed != profile {
            OfflineUserServerMap.setServer(renewed)
        }

        guard renewed.name != player.name else {
            return player
        }
        AppLog.game.info("Yggdrasil player renamed on server: \(player.name) -> \(renewed.name)")
        var updated = player
        updated.profile = UserProfile(
            id: player.profile.id,
            name: renewed.name,
            avatar: player.profile.avatar,
            lastPlayed: player.profile.lastPlayed,
            isCurrent: player.profile.isCurrent,
        )
        await updatePlayerInDataManager(updated)
        return updated
    }

    private func updatePlayerInDataManager(_ updatedPlayer: Player) async {
        let dataManager = DIContainer.shared.ui.playerDataManager
        do {
            try dataManager.updatePlayer(updatedPlayer)
            AppLog.game.debug("Updated token info in player data manager")
            NotificationCenter.default.post(
                name: .playerUpdated,
                object: nil,
                userInfo: ["updatedPlayer": updatedPlayer],
            )
        } catch {
            AppLog.game.error("Failed to save updated token: \(error.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(error)
        }
    }

    private func checkMemoryPressure() async -> Bool {
        let level = MemoryPressureChecker.check()
        guard level.isElevated else { return true }

        AppLog.game.warning("Memory pressure is \(String(describing: level)) before launching \(game.gameName)")

        let choice = await DIContainer.shared.ui.memoryPressureAlertPresenter.requestUserChoice(for: level)
        return choice == .continueAnyway
    }

    private func replaceAuthParameters(command: [String], with validatedPlayer: Player) async throws -> [String] {
        let yggdrasilProfile = OfflineUserServerMap.serverKey(for: validatedPlayer.id)

        let accessToken: String
        let commandWithAgent: [String]
        if let profile = yggdrasilProfile {
            (accessToken, commandWithAgent) = try await handleThirdPartyAuth(
                command: command,
                player: validatedPlayer,
                profile: profile,
            )
        } else {
            accessToken = validatedPlayer.authAccessToken
            commandWithAgent = command
        }

        let replacements: [String: String] = [
            "${auth_player_name}": validatedPlayer.name,
            "${auth_uuid}": validatedPlayer.id,
            "${auth_access_token}": accessToken,
            "${auth_xuid}": validatedPlayer.authXuid,
        ]
        let authReplacedCommand = commandWithAgent.map { arg in
            replacements.reduce(into: arg) { result, pair in
                result = result.replacingOccurrences(of: pair.key, with: pair.value)
            }
        }

        return replaceGameParameters(command: authReplacedCommand)
    }

    private func getThirdPartyMcToken(
        player: Player,
        profile: YggdrasilProfile?,
    ) async throws -> String {
        guard let profile else {
            return player.authAccessToken
        }
        // Custom password servers have no token exchange endpoint: the (already renewed)
        // authserver accessToken stored in the profile is the game session token.
        guard let server = YggdrasilServerPresets.server(for: profile.serverBaseURL) else {
            return profile.accessToken
        }

        let accessToken: String
        do {
            accessToken = try await DIContainer.shared.system.yggdrasilAuthService.getMinecraftToken(profile: profile, server: server)
        } catch {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
                message: "Failed to fetch Minecraft token for profile=\(profile.serverBaseURL): \(error.localizedDescription)",
            )
        }
        return accessToken
    }

    private func handleThirdPartyAuth(
        command: [String],
        player: Player,
        profile: YggdrasilProfile,
    ) async throws -> (accessToken: String, command: [String]) {
        let accessToken: String
        do {
            accessToken = try await getThirdPartyMcToken(player: player, profile: profile)
        } catch {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
                message: "Failed to fetch Minecraft token for profile=\(profile.serverBaseURL): \(error.localizedDescription)",
            )
        }

        let jarPath = AppConstants.AuthlibInjector.jarPath
        if !FileManager.default.fileExists(atPath: jarPath) {
            AppLog.game.error("Authlib Injector JAR does not exist, waiting for user selection: \(jarPath)")
            let choice = await DIContainer.shared.ui.authlibInjectorMissingPresenter.requestUserChoice()
            switch choice {
            case .continueWithoutInjector:
                return (player.authAccessToken, command)
            case .cancel:
                throw AuthlibInjectorLaunchCancelled()
            }
        }

        let serverApiRoot = URLConfig.API.AuthlibInjector.serverApiRoot(for: profile.serverBaseURL)
        let agentArg = AppConstants.AuthlibInjector.agentArgument(serverApiRoot: serverApiRoot)
        var newCommand = command
        newCommand.insert(agentArg, at: 0)
        return (accessToken, newCommand)
    }

    private func replaceGameParameters(command: [String]) -> [String] {
        let settings = DIContainer.shared.ui.gameSettingsManager

        let xms = game.xms > 0 ? game.xms : settings.globalXms
        let xmx = game.xmx > 0 ? game.xmx : settings.globalXmx

        let replacements: [String: String] = [
            "${xms}": "\(xms)",
            "${xmx}": "\(xmx)",
            "${game_directory}": AppPaths.profileDirectory(gameName: game.gameName).path,
        ]
        var replacedCommand = command.map { arg in
            replacements.reduce(into: arg) { result, pair in
                result = result.replacingOccurrences(of: pair.key, with: pair.value)
            }
        }

        if !game.jvmArguments.isEmpty {
            let advancedArgs = game.jvmArguments
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            var seen = Set<String>()
            let uniqueAdvancedArgs = advancedArgs.filter { arg in
                if seen.contains(arg) {
                    return false
                }
                seen.insert(arg)
                return true
            }
            replacedCommand.insert(contentsOf: uniqueAdvancedArgs, at: 0)
        }

        return replacedCommand
    }

    private func launchGameProcess(command: [String]) async throws {
        if game.modLoader != GameLoader.vanilla.displayName,
           AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }

        let javaExecutable = game.javaPath
        guard !javaExecutable.isEmpty else {
            throw GlobalError.configuration(
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup,
                message: "Java path is empty for game=\(game.gameName), javaPath=\(javaExecutable)",
            )
        }

        let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        AppLog.game.info("Game working directory: \(gameWorkingDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaExecutable)
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory

        if !game.environmentVariables.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in EnvironmentVariablesParser.parse(game.environmentVariables) {
                env[key] = value
            }
            process.environment = env
        }

        DIContainer.shared.core.gameProcessManager.storeProcess(gameId: game.id, userId: player.id, process: process)

        do {
            try process.run()

            _ = await MainActor.run {
                DIContainer.shared.core.gameStatusManager.setGameRunning(gameId: game.id, userId: player.id, isRunning: true)
            }
        } catch {
            AppLog.game.error("Failed to launch process: \(error.localizedDescription)")

            _ = DIContainer.shared.core.gameProcessManager.stopProcess(for: game.id, userId: player.id)
            _ = await MainActor.run {
                DIContainer.shared.core.gameStatusManager.setGameRunning(gameId: game.id, userId: player.id, isRunning: false)
            }

            throw GlobalError.gameLaunch(
                i18nKey: "error.game_launch.process_failed",
                level: .popup,
                message: "Failed to start process for game=\(game.gameName), javaPath=\(javaExecutable): \(error.localizedDescription)",
            )
        }
    }

    private func handleLaunchError(_ error: Error) async {
        AppLog.game.error("Failed to launch game: \(error.localizedDescription)")

        let globalError = GlobalError.from(error)
        DIContainer.shared.core.errorHandler.handle(globalError)
    }
}
