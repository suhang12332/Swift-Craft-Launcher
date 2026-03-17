import Foundation

extension ModPackImportViewModel {
    // MARK: - ModPack Import
    func importModPack() async {
        guard selectedModPackFile != nil,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo,
              let gameRepository = gameRepository else { return }

        // 判断整合包游戏版本是否在支持范围内（与下载整合包一致，仅支持基线版本及以上）
        if !CommonUtil.isVersionAtLeast(indexInfo.gameVersion) {
            return
        }

        isProcessingModPack = true

        // 1. 创建 profile 文件夹
        let profileCreated = await createProfileDirectories(for: gameNameValidator.gameName)

        if !profileCreated {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 2. 复制 overrides 文件（在安装依赖之前）
        let resourceDir = AppPaths.profileDirectory(gameName: gameNameValidator.gameName)
        // 先计算 overrides 文件总数
        let overridesTotal = await calculateOverridesTotal(extractedPath: extractedPath)

        // 只有当有 overrides 文件时，才提前设置 isInstalling 和 overridesTotal
        // 确保进度条能在复制开始前显示（updateOverridesProgress 会在回调中更新其他状态）
        if overridesTotal > 0 {
            await MainActor.run {
                modPackViewModel.modPackInstallState.isInstalling = true
                modPackViewModel.modPackInstallState.overridesTotal = overridesTotal
                modPackViewModel.objectWillChange.send()
            }
        }

        // 等待一小段时间，确保 UI 更新
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        let overridesSuccess = await ModPackDependencyInstaller.installOverrides(
            extractedPath: extractedPath,
            resourceDir: resourceDir
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
                modPackViewModel.objectWillChange.send()
            }
        }

        if !overridesSuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 3. 准备安装
        let tempGameInfo = GameVersionInfo(
            id: UUID(),
            gameName: gameNameValidator.gameName,
            gameIcon: AppConstants.defaultGameIcon,
            gameVersion: indexInfo.gameVersion,
            assetIndex: "",
            modLoader: indexInfo.loaderType
        )

        let (filesToDownload, requiredDependencies) = calculateInstallationCounts(from: indexInfo)

        modPackViewModel.modPackInstallState.startInstallation(
            filesTotal: filesToDownload.count,
            dependenciesTotal: requiredDependencies.count
        )

        isProcessingModPack = false

        // 4. 下载整合包文件（mod 文件）
        let filesSuccess = await ModPackDependencyInstaller.installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            gameInfo: tempGameInfo
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                modPackViewModel.objectWillChange.send()
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !filesSuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 5. 安装依赖
        let dependencySuccess = await ModPackDependencyInstaller.installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: tempGameInfo,
            resourceDir: resourceDir
        ) { [self] fileName, completed, total, type in
            Task { @MainActor in
                modPackViewModel.objectWillChange.send()
                updateModPackInstallProgress(
                    fileName: fileName,
                    completed: completed,
                    total: total,
                    type: type
                )
            }
        }

        if !dependencySuccess {
            handleModPackInstallationResult(success: false, gameName: gameNameValidator.gameName)
            return
        }

        // 6. 安装游戏本体
        let gameSuccess = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: gameNameValidator.gameName,
                    gameIcon: AppConstants.defaultGameIcon,
                    selectedGameVersion: indexInfo.gameVersion,
                    selectedModLoader: indexInfo.loaderType,
                    specifiedLoaderVersion: indexInfo.loaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: nil, // Will be set from environment
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, message in
                        Task { @MainActor in
                            Logger.shared.error("游戏设置失败: \(message)")
                            GlobalErrorHandler.shared.handle(error)
                        }
                        continuation.resume(returning: false)
                    }
                )
            }
        }

        handleModPackInstallationResult(success: gameSuccess, gameName: gameNameValidator.gameName)
    }

    func handleModPackInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("本地整合包导入完成: \(gameName)")
            // 清理不再需要的索引数据以释放内存
            modPackViewModel.clearParsedIndexInfo()
            configuration.actions.onCancel() // Use cancel to dismiss
        } else {
            Logger.shared.error("本地整合包导入失败: \(gameName)")
            // 清理已创建的游戏文件夹
            Task {
                await cleanupGameDirectories(gameName: gameName)
            }
            let globalError = GlobalError.resource(
                chineseMessage: "本地整合包导入失败",
                i18nKey: "error.resource.local_modpack_import_failed",
                level: .notification
            )
            GlobalErrorHandler.shared.handle(globalError)
            modPackViewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
            // 清理不再需要的索引数据以释放内存
            modPackViewModel.clearParsedIndexInfo()
        }
        isProcessingModPack = false
    }

    func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
        }
    }
}