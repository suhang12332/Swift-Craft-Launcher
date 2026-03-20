import Foundation

extension ModPackImportViewModel {
    // MARK: - Helper Methods
    func createProfileDirectories(for gameName: String) async -> Bool {
        let profileDirectory = AppPaths.profileDirectory(gameName: gameName)

        let subdirs = AppPaths.profileSubdirectories.map {
            profileDirectory.appendingPathComponent($0)
        }

        for dir in [profileDirectory] + subdirs {
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                Logger.shared.error("创建目录失败: \(dir.path), 错误: \(error.localizedDescription)")
                GlobalErrorHandler.shared.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "创建目录失败: \(dir.path)",
                        i18nKey: "error.filesystem.directory_creation_failed",
                        level: .notification
                    )
                )
                return false
            }
        }

        return true
    }

    func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo
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

    // MARK: - Computed Properties for UI Updates
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

    /// 整合包游戏版本是否在支持范围内
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

    // MARK: - Expose Internal Objects
    var modPackViewModelForProgress: ModPackDownloadSheetViewModel {
        modPackViewModel
    }
}
