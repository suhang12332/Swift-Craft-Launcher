//
//  ModPackImportViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Handles importing a modpack from a local file, including parsing, validation, and installation.
@MainActor
class ModPackImportViewModel: BaseGameFormViewModel {
    let modPackViewModel = ModPackDownloadSheetViewModel()

    var selectedModPackFile: URL?
    var extractedModPackPath: URL?
    var modPackIndexInfo: ModrinthIndexInfo?
    var isProcessingModPack = false
    var failedResources: [FailedModPackResource] = []
    var failedResourcesContinuation: ((Bool) -> Void)?

    let onProcessingStateChanged: (Bool) -> Void

    init(
        configuration: GameFormConfiguration,
        preselectedFile: URL? = nil,
        shouldStartProcessing: Bool = false,
        onProcessingStateChanged: @escaping (Bool) -> Void = { _ in },
    ) {
        self.onProcessingStateChanged = onProcessingStateChanged
        super.init(configuration: configuration)

        selectedModPackFile = preselectedFile
        isProcessingModPack = shouldStartProcessing
    }

    func setup(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
        modPackViewModel.setGameRepository(gameRepository)

        if selectedModPackFile != nil, isProcessingModPack {
            Task {
                await parseSelectedModPack()
            }
        }

        updateParentState()
    }

    override func performInstallation() async {
        await importModPack()
    }

    override func performCancelCleanup() async {
        modPackViewModel.modPackInstallState.reset()
        isProcessingModPack = false
        onProcessingStateChanged(false)
        modPackViewModel.clearParsedIndexInfo()
        modPackViewModel.abortFailedResources()

        let extractedPath = extractedModPackPath
        extractedModPackPath = nil
        if let extractedPath {
            await Task.detached(priority: .utility) {
                let fm = FileManager.default
                guard fm.fileExists(atPath: extractedPath.path) else { return }
                do {
                    try fm.removeItem(at: extractedPath)
                    AppLog.modPack.info("Deleted ModPack temp extracted files: \(extractedPath.path)")
                } catch {
                    AppLog.modPack.error("Failed to delete ModPack temp files: \(error.localizedDescription)")
                }
            }.value
        }

        await super.performCancelCleanup()
    }

    override func computeIsDownloading() -> Bool {
        gameSetupService.downloadState.isDownloading
            || modPackViewModel.modPackInstallState.isInstalling
            || isProcessingModPack
    }

    override func computeIsFormValid() -> Bool {
        let hasFile = selectedModPackFile != nil
        let hasInfo = modPackIndexInfo != nil
        let nameValid = gameNameValidator.isFormValid
        let gameVersionSupported = isGameVersionSupported
        return hasFile && hasInfo && nameValid && gameVersionSupported
    }
}

extension ModPackImportViewModel: FailedResourcesPresenting {
    var modPackInstallState: ModPackInstallState {
        modPackViewModel.modPackInstallState
    }
}
