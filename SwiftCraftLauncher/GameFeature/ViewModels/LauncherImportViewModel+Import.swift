import Foundation

extension LauncherImportViewModel {
    func importSelectedInstances() async {
        guard let gameRepository else { return }

        let instances = selectedImportInstances
        guard !instances.isEmpty else { return }

        isImporting = true
        defer {
            isImporting = false
            activeImportGameName = nil
            currentImportInstanceName = nil
            importProgress = nil
        }

        var importedCount = 0

        for instance in instances {
            if Task.isCancelled {
                return
            }

            let didImport = await importInstance(
                instance,
                gameRepository: gameRepository
            )

            if didImport {
                importedCount += 1
            }
        }

        guard importedCount > 0 else {
            return
        }

        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    private func importInstance(
        _ instance: ScannedLauncherInstance,
        gameRepository: GameRepository
    ) async -> Bool {
        currentImportInstanceName = instance.info.gameName
        activeImportModLoader = instance.info.modLoader

        let finalGameName = await resolvedGameName(
            for: instance.info.gameName,
            launcherType: instance.info.launcherType
        )
        activeImportGameName = finalGameName
        let targetDirectory = AppPaths.profileDirectory(gameName: finalGameName)

        do {
            copyTask = Task {
                try await InstanceFileCopier.copyGameDirectory(
                    from: instance.info.sourceGameDirectory,
                    to: targetDirectory,
                    launcherType: instance.info.launcherType
                ) { fileName, completed, total in
                    Task { @MainActor in
                        self.importProgress = (fileName, completed, total)
                    }
                }
            }

            try await copyTask?.value
            copyTask = nil
        } catch is CancellationError {
            copyTask = nil
            await performCancelCleanup()
            return false
        } catch {
            copyTask = nil
            errorHandler.handle(
                GlobalError.fileSystem(
                    chineseMessage: "复制游戏目录失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.copy_game_directory_failed",
                    level: .notification
                )
            )
            await cleanupPartialImport(gameName: finalGameName)
            return false
        }

        let didSave = await withCheckedContinuation { continuation in
            Task {
                await gameSetupService.saveGame(
                    gameName: finalGameName,
                    selectedGameVersion: instance.info.gameVersion,
                    selectedModLoader: instance.info.modLoader,
                    specifiedLoaderVersion: instance.info.modLoaderVersion,
                    pendingIconData: nil,
                    playerListViewModel: playerListViewModel,
                    gameRepository: gameRepository,
                    onSuccess: {
                        continuation.resume(returning: true)
                    },
                    onError: { error, _ in
                        self.errorHandler.handle(error)
                        continuation.resume(returning: false)
                    }
                )
            }
        }

        if !didSave {
            await cleanupPartialImport(gameName: finalGameName)
            return false
        }

        activeImportGameName = nil
        return true
    }

    private func resolvedGameName(
        for preferredName: String,
        launcherType: ImportLauncherType
    ) async -> String {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty
            ? "launcher.import.default_game_name".localized()
            : trimmedName

        if !(await gameSetupService.checkGameNameDuplicate(baseName)) {
            return baseName
        }

        let suffixBase = "\(baseName) (\(launcherType.displayName))"
        if !(await gameSetupService.checkGameNameDuplicate(suffixBase)) {
            return suffixBase
        }

        for index in 2...100 {
            let candidate = "\(suffixBase) \(index)"
            if !(await gameSetupService.checkGameNameDuplicate(candidate)) {
                return candidate
            }
        }

        return "\(suffixBase) \(UUID().uuidString.prefix(6))"
    }

    private func cleanupPartialImport(gameName: String) async {
        do {
            let fileManager = MinecraftFileManager()
            try fileManager.cleanupGameDirectories(gameName: gameName)
        } catch {
            Logger.shared.error("清理残留文件失败: \(error.localizedDescription)")
        }
        activeImportGameName = nil
    }
}
