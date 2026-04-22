import Foundation

extension ModPackImportViewModel {
    // MARK: - ModPack Import
    func importModPack() async {
        guard let archiveURL = selectedModPackFile,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo,
              let gameRepository = gameRepository else { return }

        // 判断整合包游戏版本是否在支持范围内（与下载整合包一致，仅支持基线版本及以上）
        if !CommonUtil.isVersionAtLeast(indexInfo.gameVersion) {
            return
        }

        isProcessingModPack = false

        let coordinator = ModPackInstallCoordinator(downloadService: ModPackDownloadService())
        let success = await coordinator.run(
            .init(
                archivePath: archiveURL,
                projectDetailForIcon: nil,
                gameName: gameNameValidator.gameName,
                selectedGameVersion: indexInfo.gameVersion,
                gameSetupService: gameSetupService,
                gameRepository: gameRepository,
                modPackInstallState: modPackViewModel.modPackInstallState,
                setProcessing: { _ in },
                setLastParsedIndexInfo: { [weak self] info in
                    self?.modPackIndexInfo = info
                },
                prepared: .init(
                    extractedPath: extractedPath,
                    indexInfo: indexInfo,
                    projectDetailForIcon: nil
                )
            )
        )

        handleModPackInstallationResult(success: success, gameName: gameNameValidator.gameName)
    }

    func handleModPackInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("本地整合包导入完成: \(gameName)")
            // 清理不再需要的索引数据以释放内存
            modPackViewModel.clearParsedIndexInfo()
            configuration.actions.onCancel() // Use cancel to dismiss
        } else if Task.isCancelled || gameSetupService.downloadState.isCancelled {
            Logger.shared.info("本地整合包导入已取消: \(gameName)")
            modPackViewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
            modPackViewModel.clearParsedIndexInfo()
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
            errorHandler.handle(globalError)
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
