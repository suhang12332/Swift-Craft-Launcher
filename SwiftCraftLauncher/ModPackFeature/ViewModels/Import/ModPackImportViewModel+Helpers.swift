//
//  ModPackImportViewModel+Helpers.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackImportViewModel {
    /// Creates the profile directory structure for the game.
    /// - Parameter gameName: The name of the game.
    /// - Returns: Whether all directories were created successfully.
    func createProfileDirectories(for gameName: String) async -> Bool {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)

        let subdirs = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }

        for dir in [profileDirectory] + subdirs {
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true,
                )
            } catch {
                AppLog.modPack.error("Failed to create directory: \(dir.path), error: \(error.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(
                    GlobalError.fileSystem(
                        i18nKey: "error.filesystem.directory_creation_failed",
                        level: .notification,
                    ),
                )
                return false
            }
        }

        return true
    }

    /// Calculates the files and required dependencies from the index info.
    /// - Parameter indexInfo: The parsed modpack index.
    /// - Returns: A tuple of downloadable files and required dependencies.
    func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo,
    ) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        let filesToDownload = indexInfo.files.filter { file in
            if let env = file.env, let client = env.client,
               client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
        let requiredDependencies = indexInfo.dependencies.filter {
            $0.dependencyType == "required"
        }

        return (filesToDownload, requiredDependencies)
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
    }

    var hasSelectedModPack: Bool {
        selectedModPackFile != nil
    }

    var modPackName: String {
        modPackIndexInfo?.modPackName ?? ""
    }

    var gameVersion: String {
        modPackIndexInfo?.gameVersion ?? ""
    }

    var isGameVersionSupported: Bool {
        let v = gameVersion
        return v.isEmpty || CommonUtil.isVersionAtLeast(v)
    }

    var modPackVersion: String {
        modPackIndexInfo?.modPackVersion ?? ""
    }

    var loaderInfo: String {
        guard let indexInfo = modPackIndexInfo else { return "" }
        return indexInfo.loaderVersion.isEmpty
            ? indexInfo.loaderType
            : "\(indexInfo.loaderType)-\(indexInfo.loaderVersion)"
    }

    var modPackViewModelForProgress: ModPackDownloadSheetViewModel {
        modPackViewModel
    }
}
