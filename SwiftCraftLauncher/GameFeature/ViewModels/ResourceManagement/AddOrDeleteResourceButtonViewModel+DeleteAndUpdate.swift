//
//  AddOrDeleteResourceButtonViewModel+DeleteAndUpdate.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Extension providing delete, update, and disable state management for `AddOrDeleteResourceButtonViewModel`.
extension AddOrDeleteResourceButtonViewModel {
    func confirmDelete() {
        deleteFile(fileName: effectiveFileName)
    }

    func deleteFile(fileName: String?, isUpdate: Bool = false) {
        let queryLowercased = query.lowercased()

        if queryLowercased == ResourceType.modpack.rawValue || !AppConstants.validResourceTypes.contains(queryLowercased) {
            let globalError = GlobalError.configuration(
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification,
                message: "Cannot delete: query=\(query) is modpack or not a valid resource type",
            )
            AppLog.game.error("Failed to delete file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return
        }

        guard let gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            let globalError = GlobalError.configuration(
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification,
                message: "Cannot delete: resource directory missing for query=\(query), gameName=\(gameInfo?.gameName ?? "nil")",
            )
            AppLog.game.error("Failed to delete file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return
        }

        guard let fileName else {
            let globalError = GlobalError.resource(
                i18nKey: "error.resource.file_name_missing",
                level: .notification,
                message: "Cannot delete: fileName is nil for query=\(query)",
            )
            AppLog.game.error("Failed to delete file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
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
        guard let gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            AppLog.game.error("Failed to toggle resource enabled state: resource directory does not exist")
            return
        }

        let fileName = effectiveFileName
        guard let fileName else {
            AppLog.game.error("Failed to toggle resource enabled state: missing filename")
            return
        }

        do {
            let newFileName = try ResourceEnableDisableManager.toggleDisableState(
                fileName: fileName,
                resourceDir: resourceDir,
            )
            currentFileName = newFileName
            syncDisableState(using: newFileName)
            onToggleDisableState?(isDisabled)

            if !isDisabled, type == false {
                checkForUpdate()
            }
        } catch {
            AppLog.game.error("Failed to toggle resource enabled state: \(error.localizedDescription)")
        }
    }

    func updateDisableState() {
        syncDisableState(using: effectiveFileName)
    }

    func checkForUpdate() {
        guard let gameInfo,
              type == false,
              !isDisabled,
              !project.projectId.hasPrefix("local_"), !project.projectId.hasPrefix("file_")
        else { return }

        Task {
            let result = await ModUpdateChecker.checkForUpdate(
                projectId: project.projectId,
                gameInfo: gameInfo,
                resourceType: query,
                installedFileName: effectiveFileName,
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
            AppLog.game.error("Failed to delete file: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    func performDeleteThrowing(fileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.file_not_found",
                level: .notification,
                message: "File does not exist at path: \(fileURL.path)",
            )
        }

        var hash: String?
        var gameName: String?
        if fileURL.deletingLastPathComponent().lastPathComponent.lowercased() == "mods" {
            gameName = fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            hash = DIContainer.shared.core.modScanner.sha1Hash(of: fileURL)
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            if let hash, let gameName {
                DIContainer.shared.core.modScanner.removeModHash(hash, from: gameName)
            }
        } catch {
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.file_deletion_failed",
                level: .notification,
                message: "Failed to remove item at \(fileURL.path): \(error.localizedDescription)",
            )
        }
    }
}
