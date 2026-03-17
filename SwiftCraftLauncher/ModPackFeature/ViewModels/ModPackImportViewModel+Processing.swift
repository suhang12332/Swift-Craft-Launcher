import Foundation

extension ModPackImportViewModel {
    // MARK: - ModPack Processing
    func parseSelectedModPack() async {
        guard let selectedFile = selectedModPackFile else { return }

        isProcessingModPack = true
        onProcessingStateChanged(true)

        // 解压整合包
        guard let extracted = await modPackViewModel.extractModPack(modPackPath: selectedFile) else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
            return
        }

        extractedModPackPath = extracted

        // 解析索引信息
        if let parsed = await modPackViewModel.parseModrinthIndex(extractedPath: extracted) {
            modPackIndexInfo = parsed
            let defaultName = GameNameGenerator.generateImportName(
                modPackName: parsed.modPackName,
                modPackVersion: parsed.modPackVersion,
                includeTimestamp: true
            )
            gameNameValidator.setDefaultName(defaultName)
            isProcessingModPack = false
            onProcessingStateChanged(false)
        } else {
            isProcessingModPack = false
            onProcessingStateChanged(false)
        }
    }
}
