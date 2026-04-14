import Foundation

extension AddOrDeleteResourceButtonViewModel {
    func confirmDelete() {
        deleteFile(fileName: effectiveFileName)
    }

    func deleteFile(fileName: String?, isUpdate: Bool = false) {
        let queryLowercased = query.lowercased()

        if queryLowercased == ResourceType.modpack.rawValue || !AppConstants.validResourceTypes.contains(queryLowercased) {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：不支持删除此类型的资源",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        guard let gameInfo = gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：游戏信息或资源目录无效",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        guard let fileName else {
            let globalError = GlobalError.resource(
                chineseMessage: "无法删除文件：缺少文件名信息",
                i18nKey: "error.resource.file_name_missing",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        let fileURL = resourceDir.appendingPathComponent(fileName)
        performDelete(fileURL: fileURL)
        if !isUpdate { onResourceChanged?() }
    }

    func handleInstallSuccess(newFileName: String?, newHash: String?) {
        hasDownloadedInSheet = true
        if let newHash { addScannedHash(newHash) }

        let wasUpdate = (oldFileNameForUpdate != nil)
        let oldF = oldFileNameForUpdate

        if let old = oldF {
            deleteFile(fileName: old, isUpdate: true)
            oldFileNameForUpdate = nil
        }

        if wasUpdate, let new = newFileName, let old = oldF {
            onResourceUpdated?(project.projectId, old, new, newHash)
            currentFileName = new
        } else if !type {
            currentFileName = nil
        }

        if type == false {
            checkForUpdate()
        } else {
            addButtonState = .installed
        }

        preloadedDetail = nil
    }

    func toggleDisableState() {
        guard let gameInfo = gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            Logger.shared.error("切换资源启用状态失败：资源目录不存在")
            return
        }

        let fileName = effectiveFileName
        guard let fileName else {
            Logger.shared.error("切换资源启用状态失败：缺少文件名")
            return
        }

        do {
            let newFileName = try ResourceEnableDisableManager.toggleDisableState(
                fileName: fileName,
                resourceDir: resourceDir
            )
            currentFileName = newFileName
            syncDisableState(using: newFileName)
            onToggleDisableState?(isDisabled)

            if !isDisabled && type == false {
                checkForUpdate()
            }
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }

    func updateDisableState() {
        syncDisableState(using: effectiveFileName)
    }

    func checkForUpdate() {
        guard let gameInfo = gameInfo,
              type == false,
              !isDisabled,
              !project.projectId.hasPrefix("local_") && !project.projectId.hasPrefix("file_")
        else { return }

        Task {
            let result = await ModUpdateChecker.checkForUpdate(
                projectId: project.projectId,
                gameInfo: gameInfo,
                resourceType: query,
                installedFileName: effectiveFileName
            )
            if result.hasUpdate {
                addButtonState = .update
            } else {
                addButtonState = .installed
            }
        }
    }

    func performDelete(fileURL: URL) {
        do {
            try performDeleteThrowing(fileURL: fileURL)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
        }
    }

    func performDeleteThrowing(fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GlobalError.resource(
                chineseMessage: "文件不存在: \(fileURL.lastPathComponent)",
                i18nKey: "error.resource.file_not_found",
                level: .notification
            )
        }

        var hash: String?
        var gameName: String?
        if fileURL.deletingLastPathComponent().lastPathComponent.lowercased() == "mods" {
            gameName = fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            hash = ModScanner.sha1Hash(of: fileURL)
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            if let hash, let gameName {
                ModScanner.shared.removeModHash(hash, from: gameName)
            }
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage:
                    "删除文件失败: \(fileURL.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.file_deletion_failed",
                level: .notification
            )
        }
    }
}
