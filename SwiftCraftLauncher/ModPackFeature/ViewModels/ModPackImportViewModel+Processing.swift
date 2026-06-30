//
//  ModPackImportViewModel+Processing.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackImportViewModel {
    /// Parses the selected modpack archive, extracts it, and populates the form fields.
    func parseSelectedModPack() async {
        guard let selectedFile = selectedModPackFile else { return }

        isProcessingModPack = true
        onProcessingStateChanged(true)

        let downloadService = ModPackDownloadService()
        let coordinator = ModPackInstallCoordinator(downloadService: downloadService)
        guard let prepared = await coordinator.prepare(archivePath: selectedFile) else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
            return
        }

        extractedModPackPath = prepared.extractedPath
        modPackIndexInfo = prepared.indexInfo
        let defaultName = GameNameGenerator.generateImportName(
            modPackName: prepared.indexInfo.modPackName,
            modPackVersion: prepared.indexInfo.modPackVersion,
            includeTimestamp: true
        )
        gameNameValidator.setDefaultName(defaultName)
        isProcessingModPack = false
        onProcessingStateChanged(false)
    }
}
