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
        if player.isYggdrasilAccount {
            return try await refreshYggdrasilCredentialBeforeLaunch()
        }
        guard player.isOnlineAccount else {
            return player
        }

        AppLog.game.info("Verifying player \(player.name) token before launch")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = DIContainer.shared.ui.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id, authMethod: playerWithCredential.authMethod) {
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

    /// 启动前刷新 Yggdrasil 账号的令牌。
    ///
    /// OAuth 预设沿用"刷新失败静默降级"策略;密码登录(自定义服务器)则由
    /// 续期状态机保证令牌可用,无法恢复时中止启动并给出明确错误。
    private func refreshYggdrasilCredentialBeforeLaunch() async throws -> Player {
        let dataManager = DIContainer.shared.ui.playerDataManager
        guard let credential = player.credential
            ?? dataManager.loadCredential(userId: player.id, authMethod: player.authMethod),
            let serverBaseURL = player.yggdrasilServerBaseURL else {
            return player
        }

        do {
            let outcome = try await DIContainer.shared.system.yggdrasilAuthService.ensureFreshYggdrasilCredential(
                credential,
                serverBaseURL: serverBaseURL,
            )

            var updated = player
            updated.credential = outcome.credential
            if let newName = outcome.updatedName, !newName.isEmpty, newName != player.name {
                updated.profile.name = newName
                AppLog.game.info("Yggdrasil player renamed on server: \(player.name) -> \(newName)")
            }

            if updated != player {
                await updatePlayerInDataManager(updated)
            }
            return updated
        } catch YggdrasilAuthService.YggdrasilRenewalError.passwordRejected(let cleared) {
            // 记住的密码已被修改:写回清除后的凭据,并要求用户重新登录
            _ = dataManager.saveCredential(cleared)
            throw GlobalError.authentication(
                i18nKey: "yggdrasil.error.password_changed",
                level: .popup,
                message: "Saved password rejected for user \(cleared.userId)",
            )
        } catch {
            if credential.authMethod == .yggdrasilOAuth {
                // OAuth 预设:刷新失败沿用旧令牌(与历史行为一致)
                AppLog.game.error("Yggdrasil OAuth token refresh failed, keeping existing token: \(error.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
                return player
            }
            // 密码登录:令牌已失效且无法静默恢复,必须中止
            throw error
        }
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
        let accessToken: String
        let commandWithAgent: [String]
        if validatedPlayer.isYggdrasilAccount, let serverBaseURL = validatedPlayer.yggdrasilServerBaseURL {
            (accessToken, commandWithAgent) = try await handleThirdPartyAuth(
                command: command,
                player: validatedPlayer,
                serverBaseURL: serverBaseURL,
            )
        } else {
            accessToken = validatedPlayer.authAccessToken
            commandWithAgent = command
        }

        let replacements: [String: String] = [
            "${auth_player_name}": player.name,
            "${auth_uuid}": player.id,
            "${auth_access_token}": accessToken,
            "${auth_xuid}": player.authXuid,
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
        serverBaseURL: String,
    ) async throws -> String {
        guard let server = YggdrasilServerPresets.server(for: serverBaseURL) else {
            return player.authAccessToken
        }

        let accessToken: String
        do {
            accessToken = try await DIContainer.shared.system.yggdrasilAuthService.getMinecraftToken(
                profileId: player.id,
                accessToken: player.authAccessToken,
                server: server,
            )
        } catch {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
                message: "Failed to fetch Minecraft token for profile=\(serverBaseURL): \(error.localizedDescription)",
            )
        }
        return accessToken
    }

    private func handleThirdPartyAuth(
        command: [String],
        player: Player,
        serverBaseURL: String,
    ) async throws -> (accessToken: String, command: [String]) {
        let accessToken: String
        do {
            accessToken = try await getThirdPartyMcToken(player: player, serverBaseURL: serverBaseURL)
        } catch {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
                message: "Failed to fetch Minecraft token for profile=\(serverBaseURL): \(error.localizedDescription)",
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

        let serverApiRoot = URLConfig.API.AuthlibInjector.serverApiRoot(for: serverBaseURL)
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
