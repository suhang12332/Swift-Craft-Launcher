import Foundation

extension LauncherImportViewModel {
    // MARK: - Import Methods

    /// 直接从路径导入实例（所有启动器都使用此方法）
    func importSelectedInstancePath(_ instancePath: URL) async {
        guard let gameRepository = gameRepository else { return }

        isImporting = true
        defer { isImporting = false }

        let instanceName = instancePath.lastPathComponent

        // 从实例路径推断启动器基础路径
        let basePath = inferBasePath(from: instancePath)

        let parser = LauncherInstanceParserFactory.createParser(for: selectedLauncherType)

        // 解析实例信息
        let instanceInfo: ImportInstanceInfo
        do {
            guard let parsedInfo = try parser.parseInstance(at: instancePath, basePath: basePath) else {
                Logger.shared.error("解析实例失败: \(instanceName) - 返回 nil")
                GlobalErrorHandler.shared.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "解析实例 \(instanceName) 失败：无法获取实例信息",
                        i18nKey: "error.filesystem.parse_instance_failed",
                        level: .notification
                    )
                )
                return
            }
            instanceInfo = parsedInfo
        } catch {
            Logger.shared.error("解析实例失败: \(instanceName) - \(error.localizedDescription)")
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "解析实例 \(instanceName) 失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.parse_instance_failed",
                    level: .notification
                )
            )
            return
        }

        // 验证实例必须有版本
        guard !instanceInfo.gameVersion.isEmpty else {
            Logger.shared.error("实例 \(instanceName) 没有游戏版本")
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "实例 \(instanceName) 没有游戏版本，无法导入",
                    i18nKey: "error.filesystem.instance_no_version",
                    level: .notification
                )
            )
            return
        }

        // 验证 Mod Loader 支持，错误已显示，此处仅记录日志
        guard AppConstants.modLoaders.contains(instanceInfo.modLoader.lowercased()) else {
            Logger.shared.error("实例 \(instanceName) 使用了不支持的 Mod Loader: \(instanceInfo.modLoader)")
            return
        }

        // 生成游戏名称（如果用户没有自定义）
        let finalGameName = gameNameValidator.gameName.isEmpty
            ? instanceInfo.gameName
            : gameNameValidator.gameName

        // 1. 先复制游戏目录（保留 mods、config 等文件）
        let targetDirectory = AppPaths.profileDirectory(gameName: finalGameName)

        do {
            // 创建复制任务，以便可以取消
            copyTask = Task {
                try await InstanceFileCopier.copyGameDirectory(
                    from: instanceInfo.sourceGameDirectory,
                    to: targetDirectory,
                    launcherType: instanceInfo.launcherType
                ) { fileName, completed, total in
                    Task { @MainActor in
                        self.importProgress = (fileName, completed, total)
                    }
                }
            }

            try await copyTask?.value
            copyTask = nil

            Logger.shared.info("成功复制游戏目录: \(instanceName) -> \(finalGameName)")
        } catch is CancellationError {
            Logger.shared.info("复制游戏目录已取消: \(instanceName)")
            copyTask = nil
            // 清理已复制的文件
            await performCancelCleanup()
            return
        } catch {
            Logger.shared.error("复制游戏目录失败: \(error.localizedDescription)")
            copyTask = nil
            GlobalErrorHandler.shared.handle(
                GlobalError.fileSystem(
                    chineseMessage: "复制游戏目录失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.copy_game_directory_failed",
                    level: .notification
                )
            )
            return
        }

        // 2. 下载游戏和 Mod Loader（只下载缺失的，不覆盖已有）
        let downloadSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: finalGameName,
                    gameIcon: AppConstants.defaultGameIcon,
                    selectedGameVersion: instanceInfo.gameVersion,
                    selectedModLoader: instanceInfo.modLoader,
                    specifiedLoaderVersion: instanceInfo.modLoaderVersion,
                    pendingIconData: nil,  // 从启动器导入时不导入图标
                    playerListViewModel: playerListViewModel,
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Logger.shared.error("游戏下载失败: \(message)")
                        GlobalErrorHandler.shared.handle(error)
                        continuation.resume(returning: false)
                    }
                )
            }
        }

        if !downloadSuccess {
            Logger.shared.error("导入实例失败: \(instanceName)")
            return
        }

        Logger.shared.info("成功导入实例: \(instanceName) -> \(finalGameName)")

        // 导入完成
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }
}
