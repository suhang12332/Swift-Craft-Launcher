import Foundation

/// Minecraft 启动命令生成器
struct MinecraftLaunchCommand {
    let player: Player?
    let game: GameVersionInfo
    let gameRepository: GameRepository
    
    /// 启动游戏（静默版本）
    public func launchGame() async {
        do {
            try await launchGameThrowing()
        } catch {
            await handleLaunchError(error)
        }
    }
    
    /// 停止游戏
    public func stopGame() async {
        let success = GameProcessManager.shared.stopProcess(for: game.id)
        if success {
            _ = await MainActor.run {
                gameRepository.updateGameStatusSilently(id: game.id, isRunning: false)
            }
        }
    }
    
    /// 启动游戏（抛出异常版本）
    /// - Throws: GlobalError 当启动失败时
    public func launchGameThrowing() async throws {
        let command = game.launchCommand
        try await launchGameProcess(command: replaceAuthParameters(command: command))
    }
    
    private func replaceAuthParameters(command: [String]) -> [String] {
        guard let player = player else {
            Logger.shared.warning("没有选择玩家，使用默认认证参数")
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
        guard let gameWorkingDirectory = AppPaths.profileDirectory(gameName: game.gameName) else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取游戏工作目录: \(game.gameName)",
                i18nKey: "error.configuration.game_working_directory_not_found",
                level: .popup
            )
        }
        
        Logger.shared.info("启动游戏进程: \(javaPath) \(command.joined(separator: " "))")
        Logger.shared.info("游戏工作目录: \(gameWorkingDirectory.path)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath + "/java")
        process.arguments = command
        process.currentDirectoryURL = gameWorkingDirectory
        
        // 存储进程到管理器
        GameProcessManager.shared.storeProcess(gameId: game.id, process: process)
        
        _ = await MainActor.run {
            gameRepository.updateGameStatusSilently(id: game.id, isRunning: true)
        }
        
        do {
            try process.run()
        } catch {
            Logger.shared.error("启动进程失败: \(error.localizedDescription)")
            _ = gameRepository.updateGameStatusSilently(id: game.id, isRunning: false)
            throw GlobalError.gameLaunch(
                chineseMessage: "启动游戏进程失败: \(error.localizedDescription)",
                i18nKey: "error.game_launch.process_failed",
                level: .popup
            )
        }
        
        let gameId = game.id
        process.terminationHandler = { _ in
            Task { @MainActor in
                _ = self.gameRepository.updateGameStatusSilently(id: gameId, isRunning: false)
                // 清理进程管理器中的进程
                GameProcessManager.shared.cleanupTerminatedProcesses()
            }
        }
    }
    
    /// 验证 Java 路径
    /// - Returns: 有效的 Java 路径
    /// - Throws: GlobalError 当 Java 路径无效时
    private func validateJavaPath() throws -> String {
        let javaPath = game.javaPath.isEmpty ? GameSettingsManager.shared.defaultJavaPath : game.javaPath
        
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
        _ = gameRepository.updateGameStatusSilently(id: game.id, isRunning: false)
        
        // 使用全局错误处理器处理错误
        let globalError = GlobalError.from(error)
        GlobalErrorHandler.shared.handle(globalError)
    }
}
 
