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
    let player: Player?
    let game: GameVersionInfo
    private let minecraftAuthService: MinecraftAuthService
    private let yggdrasilAuthService: YggdrasilAuthService
    private let gameSettingsManager: GameSettingsManager
    private let gameProcessManager: GameProcessManager
    private let gameStatusManager: GameStatusManager

    init(
        player: Player?,
        game: GameVersionInfo,
        minecraftAuthService: MinecraftAuthService = AppServices.minecraftAuthService,
        yggdrasilAuthService: YggdrasilAuthService = AppServices.yggdrasilAuthService,
        gameSettingsManager: GameSettingsManager = AppServices.gameSettingsManager,
        gameProcessManager: GameProcessManager = AppServices.gameProcessManager,
        gameStatusManager: GameStatusManager = AppServices.gameStatusManager,
    ) {
        self.player = player
        self.game = game
        self.minecraftAuthService = minecraftAuthService
        self.yggdrasilAuthService = yggdrasilAuthService
        self.gameSettingsManager = gameSettingsManager
        self.gameProcessManager = gameProcessManager
        self.gameStatusManager = gameStatusManager
    }

    func launchGame() async {
        do {
            try await launchGameThrowing()
        } catch {
            await handleLaunchError(error)
        }
    }

    func stopGame() async {
        let userId = player?.id ?? ""
        _ = gameProcessManager.stopProcess(for: game.id, userId: userId)
    }

    func launchGameThrowing() async throws {
        let validatedPlayer = try await validatePlayerTokenBeforeLaunch()

        let command = game.launchCommand
        try await launchGameProcess(
            command: try await replaceAuthParameters(command: command, with: validatedPlayer),
        )
    }

    private func validatePlayerTokenBeforeLaunch() async throws -> Player? {
        guard let player else {
            Logger.shared.warning("没有选择玩家，使用默认认证参数")
            return nil
        }

        guard player.isOnlineAccount else {
            return player
        }

        Logger.shared.info("启动游戏前验证玩家 \(player.name) 的Token")

        var playerWithCredential = player
        if playerWithCredential.credential == nil {
            let dataManager = AppServices.playerDataManager
            if let credential = dataManager.loadCredential(userId: playerWithCredential.id) {
                playerWithCredential.credential = credential
            }
        }

        let validatedPlayer = try await minecraftAuthService.validateAndRefreshPlayerTokenThrowing(for: playerWithCredential)

        if validatedPlayer.authAccessToken != player.authAccessToken {
            Logger.shared.info("玩家 \(player.name) 的Token已更新，保存到数据管理器")
            await updatePlayerInDataManager(validatedPlayer)
        }

        return validatedPlayer
    }

    private func updatePlayerInDataManager(_ updatedPlayer: Player) async {
        let dataManager = AppServices.playerDataManager
        let success = dataManager.updatePlayerSilently(updatedPlayer)
        if success {
            Logger.shared.debug("已更新玩家数据管理器中的Token信息")
            NotificationCenter.default.post(
                name: .playerUpdated,
                object: nil,
                userInfo: ["updatedPlayer": updatedPlayer],
            )
        }
    }

    private func replaceAuthParameters(command: [String], with validatedPlayer: Player?) async throws -> [String] {
        guard let player = validatedPlayer else {
            Logger.shared.warning("没有验证的玩家，使用默认认证参数")
            return replaceGameParameters(command: command)
        }

        let yggdrasilProfile = OfflineUserServerMap.serverKey(for: player.id)
        let (accessToken, commandWithAgent) = try await handleThirdPartyAuth(
            command: command,
            player: player,
            profile: yggdrasilProfile,
        )

        let authReplacedCommand = commandWithAgent.map { arg -> String in
            let mutableArg = NSMutableString(string: arg)
            mutableArg.replaceOccurrences(
                of: "${auth_player_name}",
                with: player.name,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            mutableArg.replaceOccurrences(
                of: "${auth_uuid}",
                with: player.id,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            mutableArg.replaceOccurrences(
                of: "${auth_access_token}",
                with: accessToken,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            mutableArg.replaceOccurrences(
                of: "${auth_xuid}",
                with: player.authXuid,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            return mutableArg as String
        }

        return replaceGameParameters(command: authReplacedCommand)
    }

    private func handleThirdPartyAuth(
        command: [String],
        player: Player,
        profile: YggdrasilProfile?,
    ) async throws -> (accessToken: String, command: [String]) {
        guard let profile,
              let server = YggdrasilServerPresets.server(for: profile.serverBaseURL) else {
            return (player.authAccessToken, command)
        }

        let accessToken: String
        do {
            accessToken = try await yggdrasilAuthService.getMinecraftToken(profile: profile, server: server)
        } catch {
            throw GlobalError.authentication(
                chineseMessage: "获取访问令牌失败",
                i18nKey: "error.authentication.token_fetch_failed",
                level: .popup,
            )
        }

        let jarPath = AppConstants.AuthlibInjector.jarPath
        if !FileManager.default.fileExists(atPath: jarPath) {
            Logger.shared.warning("Authlib Injector JAR 不存在，等待用户选择: \(jarPath)")
            let choice = await AppServices.authlibInjectorMissingPresenter.requestUserChoice()
            switch choice {
            case .continueWithoutInjector:
                return (accessToken, command)
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
        let settings = gameSettingsManager

        let xms = game.xms > 0 ? game.xms : settings.globalXms
        let xmx = game.xmx > 0 ? game.xmx : settings.globalXmx

        var replacedCommand = command.map { arg -> String in
            let mutableArg = NSMutableString(string: arg)
            let xmsString = "\(xms)"
            let xmxString = "\(xmx)"
            mutableArg.replaceOccurrences(
                of: "${xms}",
                with: xmsString,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            mutableArg.replaceOccurrences(
                of: "${xmx}",
                with: xmxString,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length),
            )
            return mutableArg as String
        }

        if !game.jvmArguments.isEmpty {
            let advancedArgs = game.jvmArguments
                .components(separatedBy: " ")
                .filter { !$0.isEmpty }
            var seen = Set<String>()
            let uniqueAdvancedArgs = advancedArgs.filter { arg in
                if seen.contains(arg) { return false }
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
                chineseMessage: "Java 路径未设置",
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup,
            )
        }

        let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        Logger.shared.info("游戏工作目录: \(gameWorkingDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaExecutable)
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory

        if !game.environmentVariables.isEmpty {
            var env = ProcessInfo.processInfo.environment
            let envItems = game.environmentVariables.split(whereSeparator: \.isWhitespace)
            for pair in envItems {
                if let equalIndex = pair.firstIndex(of: "=") {
                    let key = String(pair[..<equalIndex])
                    let value = String(pair[pair.index(after: equalIndex)...])
                    env[key] = value
                }
            }
            process.environment = env
        }

        let userId = player?.id ?? ""
        gameProcessManager.storeProcess(gameId: game.id, userId: userId, process: process)

        do {
            try process.run()

            _ = await MainActor.run {
                gameStatusManager.setGameRunning(gameId: game.id, userId: userId, isRunning: true)
            }
        } catch {
            Logger.shared.error("启动进程失败: \(error.localizedDescription)")

            _ = gameProcessManager.stopProcess(for: game.id, userId: userId)
            _ = await MainActor.run {
                gameStatusManager.setGameRunning(gameId: game.id, userId: userId, isRunning: false)
            }

            throw GlobalError.gameLaunch(
                chineseMessage: "启动游戏进程失败: \(error.localizedDescription)",
                i18nKey: "error.game_launch.process_failed",
                level: .popup,
            )
        }
    }

    private func handleLaunchError(_ error: Error) async {
        Logger.shared.error("启动游戏失败：\(error.localizedDescription)")

        let globalError = GlobalError.from(error)
        AppServices.errorHandler.handle(globalError)
    }
}
