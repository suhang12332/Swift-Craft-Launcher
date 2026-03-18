import Foundation

extension ModPackImportViewModel {
    // MARK: - ModPack Processing
    func parseSelectedModPack() async {
        guard let selectedFile = selectedModPackFile else { return }

        isProcessingModPack = true
        onProcessingStateChanged(true)

        let downloadService = ModPackDownloadService()
        let coordinator = ModPackInstallCoordinator(downloadService: downloadService)
        guard let prepared = await coordinator.prepare(source: .localArchive(selectedFile)) else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
            return
        }

        extractedModPackPath = prepared.extractedPath

        // 解析索引信息
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
