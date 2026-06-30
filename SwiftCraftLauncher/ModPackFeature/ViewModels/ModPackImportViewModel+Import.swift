//
//  ModPackImportViewModel+Import.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackImportViewModel {
    /// Performs the full modpack import flow: runs the install coordinator and handles the result.
    func importModPack() async {
        guard let archiveURL = selectedModPackFile,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo,
              let gameRepository = gameRepository else { return }

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

    /// Handles the final result of a modpack installation.
    /// - Parameters:
    ///   - success: Whether installation succeeded.
    ///   - gameName: The name of the game being installed.
    func handleModPackInstallationResult(success: Bool, gameName: String) {
        if success {
            Logger.shared.info("本地整合包导入完成: \(gameName)")
            configuration.actions.onCancel() // Use cancel to dismiss
        } else if Task.isCancelled || gameSetupService.downloadState.isCancelled {
            Logger.shared.info("本地整合包导入已取消: \(gameName)")
            modPackViewModel.modPackInstallState.reset()
            gameSetupService.downloadState.reset()
        } else {
            Logger.shared.error("本地整合包导入失败: \(gameName)")
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
        }
        modPackViewModel.clearParsedIndexInfo()
        isProcessingModPack = false
    }

    /// Cleans up game directories on the file system.
    /// - Parameter gameName: The name of the game whose directories should be removed.
    func cleanupGameDirectories(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
        }
    }
}
