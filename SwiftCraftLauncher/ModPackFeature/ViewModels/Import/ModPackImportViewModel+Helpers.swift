//
//  ModPackImportViewModel+Helpers.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackImportViewModel {
    func createProfileDirectories(for gameName: String) async -> Bool {
        await MinecraftFileManager.createProfileDirectories(for: gameName)
    }

    func calculateInstallationCounts(
        from indexInfo: ModrinthIndexInfo,
    ) -> ([ModrinthIndexFile], [ModrinthIndexProjectDependency]) {
        MinecraftFileManager.calculateInstallationCounts(from: indexInfo)
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
