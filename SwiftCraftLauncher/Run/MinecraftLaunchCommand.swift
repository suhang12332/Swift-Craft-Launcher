import Foundation
import AVFoundation
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
        // 停止进程，terminationHandler 会自动处理错误监控停止和状态更新
        _ = GameProcessManager.shared.stopProcess(for: game.id)
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
            // 同步更新内存中的玩家列表（避免下次启动仍使用旧 token）
            NotificationCenter.default.post(
                name: PlayerSkinService.playerUpdatedNotification,
                object: nil,
                userInfo: ["updatedPlayer": updatedPlayer]
            )
        }
    }

    private func replaceAuthParameters(command: [String], with validatedPlayer: Player?) -> [String] {
        guard let player = validatedPlayer else {
            Logger.shared.warning("没有验证的玩家，使用默认认证参数")
            return replaceGameParameters(command: command)
        }

        // 使用 NSMutableString 避免链式调用创建多个临时字符串
        let authReplacedCommand = command.map { arg -> String in
            let mutableArg = NSMutableString(string: arg)
            mutableArg.replaceOccurrences(
                of: "${auth_player_name}",
                with: player.name,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            mutableArg.replaceOccurrences(
                of: "${auth_uuid}",
                with: player.id,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            mutableArg.replaceOccurrences(
                of: "${auth_access_token}",
                with: player.authAccessToken,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            mutableArg.replaceOccurrences(
                of: "${auth_xuid}",
                with: player.authXuid,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            return mutableArg as String
        }

        return replaceGameParameters(command: authReplacedCommand)
    }

    private func replaceGameParameters(command: [String]) -> [String] {
        let settings = GameSettingsManager.shared

        // 内存设置：优先使用游戏配置，游戏没配置则使用全局
        let xms = game.xms > 0 ? game.xms : settings.globalXms
        let xmx = game.xmx > 0 ? game.xmx : settings.globalXmx

        // 使用 NSMutableString 避免链式调用创建多个临时字符串
        var replacedCommand = command.map { arg -> String in
            let mutableArg = NSMutableString(string: arg)
            let xmsString = "\(xms)"
            let xmxString = "\(xmx)"
            mutableArg.replaceOccurrences(
                of: "${xms}",
                with: xmsString,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            mutableArg.replaceOccurrences(
                of: "${xmx}",
                with: xmxString,
                options: [],
                range: NSRange(location: 0, length: mutableArg.length)
            )
            return mutableArg as String
        }

        // 在运行时拼接高级设置的JVM参数
        // 逻辑：如果有自定义JVM参数则直接使用，否则使用垃圾回收器+性能优化参数
        if !game.jvmArguments.isEmpty {
            // 将自定义JVM参数插入到命令数组的开头（java命令之后），并去重保持顺序
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

    /// 启动游戏进程
    /// - Parameter command: 启动命令数组
    /// - Throws: GlobalError 当启动失败时
    private func launchGameProcess(command: [String]) async throws {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // 直接使用游戏指定的Java路径
        let javaExecutable = game.javaPath
        guard !javaExecutable.isEmpty else {
            throw GlobalError.configuration(
                chineseMessage: "Java 路径未设置",
                i18nKey: "error.configuration.java_path_not_set",
                level: .popup
            )
        }

        // 获取游戏工作目录
        let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName)

        Logger.shared.info("启动游戏进程: \(javaExecutable) \(command.joined(separator: " "))")
        Logger.shared.info("游戏工作目录: \(gameWorkingDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaExecutable)
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory

        // 设置环境变量（高级设置）
        if !game.environmentVariables.isEmpty {
            var env = ProcessInfo.processInfo.environment
            let envLines = game.environmentVariables.components(separatedBy: "\n")
            for line in envLines {
                if let equalIndex = line.firstIndex(of: "=") {
                    let key = String(line[..<equalIndex])
                    let value = String(line[line.index(after: equalIndex)...])
                    env[key] = value
                }
            }
            process.environment = env
        }

        // 存储进程到管理器（会自动设置终止处理器）
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

    /// 处理启动错误
    /// - Parameter error: 启动错误
    private func handleLaunchError(_ error: Error) async {
        Logger.shared.error("启动游戏失败：\(error.localizedDescription)")

        // 使用全局错误处理器处理错误
        let globalError = GlobalError.from(error)
        GlobalErrorHandler.shared.handle(globalError)
    }
}
