import Foundation

/// Minecraft 启动命令生成器
struct MinecraftLaunchCommand {
    let player: Player?
    let game: GameVersionInfo
    let gameRepository: GameRepository

    /// 启动游戏（静默版本）
    func launchGame() async {
        do {
            try await launchGameThrowing()
        } catch {
            await handleLaunchError(error)
        }
    }

    /// 停止游戏
    func stopGame() async {
        let success = GameProcessManager.shared.stopProcess(for: game.id)
        if success {
            _ = await MainActor.run {
                GameStatusManager.shared.setGameRunning(gameId: game.id, isRunning: false)
            }
        }
    }

    /// 启动游戏（抛出异常版本）
    /// - Throws: GlobalError 当启动失败时
    func launchGameThrowing() async throws {
        // 在启动游戏前验证并刷新Token（如果需要）
        let validatedPlayer = try await validatePlayerTokenBeforeLaunch()

        let command = game.launchCommand
        try await launchGameProcess(command: replaceAuthParameters(command: command, with: validatedPlayer))
    }

    /// 在启动游戏前验证玩家Token
    /// - Returns: 验证后的玩家对象
    /// - Throws: GlobalError 当验证失败时
    private func validatePlayerTokenBeforeLaunch() async throws -> Player? {
        guard let player = player else {
            Logger.shared.warning("没有选择玩家，使用默认认证参数")
            return nil
        }

        // 如果是离线账户，直接返回
        guard player.isOnlineAccount else {
            return player
        }

        Logger.shared.info("启动游戏前验证玩家 \(player.name) 的Token")

        // 验证并尝试刷新Token
        let authService = MinecraftAuthService.shared
        let validatedPlayer = try await authService.validateAndRefreshPlayerTokenThrowing(for: player)

        // 如果Token被更新了，需要保存到PlayerDataManager
        if validatedPlayer.authAccessToken != player.authAccessToken {
            Logger.shared.info("玩家 \(player.name) 的Token已更新，保存到数据管理器")
            await updatePlayerInDataManager(validatedPlayer)
        }

        return validatedPlayer
    }

    /// 更新PlayerDataManager中的玩家信息
    /// - Parameter updatedPlayer: 更新后的玩家对象
    private func updatePlayerInDataManager(_ updatedPlayer: Player) async {
        let dataManager = PlayerDataManager()
        let success = dataManager.updatePlayerSilently(updatedPlayer)
        if success {
            Logger.shared.debug("已更新玩家数据管理器中的Token信息")
        }
    }

    private func replaceAuthParameters(command: [String], with validatedPlayer: Player?) -> [String] {
        guard let player = validatedPlayer else {
            Logger.shared.warning("没有验证的玩家，使用默认认证参数")
            return replaceGameParameters(command: command)
        }

        let authReplacedCommand = command.map { arg in
            return arg
                .replacingOccurrences(of: "${auth_player_name}", with: player.name)
                .replacingOccurrences(of: "${auth_uuid}", with: player.id)
                .replacingOccurrences(of: "${auth_access_token}", with: player.authAccessToken)
                .replacingOccurrences(of: "${auth_xuid}", with: player.authXuid)
        }

        return replaceGameParameters(command: authReplacedCommand)
    }

    private func replaceGameParameters(command: [String]) -> [String] {
        let settings = GameSettingsManager.shared

        // 内存设置：优先使用游戏配置，游戏没配置则使用全局
        let xms = game.xms > 0 ? game.xms : settings.globalXms
        let xmx = game.xmx > 0 ? game.xmx : settings.globalXmx

        return command.map { arg in
            return arg
                .replacingOccurrences(of: "${xms}", with: "\(xms)")
                .replacingOccurrences(of: "${xmx}", with: "\(xmx)")
        }
    }

    /// 启动游戏进程
    /// - Parameter command: 启动命令数组
    /// - Throws: GlobalError 当启动失败时
    private func launchGameProcess(command: [String]) async throws {
        // 验证 Java 路径
        let javaPath = try validateJavaPath()

        // 获取游戏工作目录
        let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        Logger.shared.info("启动游戏进程: \(javaPath) \(command.joined(separator: " "))")
        Logger.shared.info("游戏工作目录: \(gameWorkingDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath + "/java")
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory

        // 设置进程终止处理器（在启动前设置）
        let gameId = game.id
        process.terminationHandler = { _ in
            Task { @MainActor in
                GameStatusManager.shared.setGameRunning(gameId: gameId, isRunning: false)
                // 清理进程管理器中的进程
                GameProcessManager.shared.cleanupTerminatedProcesses()
            }
        }

        // 存储进程到管理器
        GameProcessManager.shared.storeProcess(gameId: game.id, process: process)

        do {
            try process.run()

            // 进程启动后立即设置状态为运行中
            _ = await MainActor.run {
                GameStatusManager.shared.setGameRunning(gameId: game.id, isRunning: true)
            }
        } catch {
            Logger.shared.error("启动进程失败: \(error.localizedDescription)")

            // 启动失败时清理进程并重置状态
            _ = GameProcessManager.shared.stopProcess(for: game.id)
            _ = await MainActor.run {
                GameStatusManager.shared.setGameRunning(gameId: game.id, isRunning: false)
            }

            throw GlobalError.gameLaunch(
                chineseMessage: "启动游戏进程失败: \(error.localizedDescription)",
                i18nKey: "error.game_launch.process_failed",
                level: .popup
            )
        }
    }

    /// 验证 Java 路径
    /// - Returns: 有效的 Java 路径
    /// - Throws: GlobalError 当 Java 路径无效时
    private func validateJavaPath() throws -> String {
        var javaPath: String
        
        // 如果游戏有指定的Java路径，使用指定的路径
        if !game.javaPath.isEmpty {
            javaPath = game.javaPath
        } else {
            // 否则尝试自动匹配Java版本
            if let recommendedJava = GameSettingsManager.shared.javaVersionManager.getRecommendedJavaVersion(for: game.gameVersion) {
                javaPath = recommendedJava.path
                Logger.shared.info("自动匹配Java版本: \(recommendedJava.displayName) (\(recommendedJava.version))")
            } else {
                // 如果自动匹配失败，使用默认路径
                javaPath = GameSettingsManager.shared.defaultJavaPath
                Logger.shared.warning("无法自动匹配Java版本，使用默认路径: \(javaPath)")
            }
        }

        guard !javaPath.isEmpty else {
            throw GlobalError.configuration(
                chineseMessage: "Java 路径未设置",
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup
            )
        }

        let javaExecutable = javaPath + "/java"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: javaExecutable) else {
            throw GlobalError.configuration(
                chineseMessage: "Java 可执行文件不存在: \(javaExecutable)",
                i18nKey: "error.configuration.java_executable_not_found",
                level: .popup
            )
        }

        // 验证 Java 可执行文件是否有执行权限
        guard fileManager.isExecutableFile(atPath: javaExecutable) else {
            throw GlobalError.configuration(
                chineseMessage: "Java 可执行文件没有执行权限: \(javaExecutable)",
                i18nKey: "error.configuration.java_executable_no_permission",
                level: .popup
            )
        }

        return javaPath
    }

    /// 处理启动错误
    /// - Parameter error: 启动错误
    private func handleLaunchError(_ error: Error) async {
        Logger.shared.error("启动游戏失败：\(error.localizedDescription)")

        // 使用全局错误处理器处理错误
        let globalError = GlobalError.from(error)
        GlobalErrorHandler.shared.handle(globalError)
    }
}
