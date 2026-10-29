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

        await removeTemporaryArtifacts()

        await super.performCancelCleanup()
    }

    /// Clears preview state and temporary files when the sheet closes without
    /// an active installation. An already installed game is left untouched.
    func cleanupPreviewState() async {
        modPackViewModel.modPackInstallState.reset()
        modPackViewModel.clearParsedIndexInfo()
        modPackViewModel.abortFailedResources()
        isProcessingModPack = false
        onProcessingStateChanged(false)

        await removeTemporaryArtifacts()
    }

    /// Deletes the copied archive and the extracted preview directory.
    private func removeTemporaryArtifacts() async {
        let extractedPath = extractedModPackPath
        let archiveURL = selectedModPackFile

        extractedModPackPath = nil
        selectedModPackFile = nil
        modPackIndexInfo = nil

        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            if let extractedPath {
                try? fileManager.removeItem(at: extractedPath)
            }

            // The archive always lives in a launcher temp purpose directory;
            // delete its per-import folder as well.
            if let archiveURL, TemporaryFile.isTemporary(archiveURL) {
                try? fileManager.removeItem(at: archiveURL.deletingLastPathComponent())
            }
        }.value
    }

    override func computeIsDownloading() -> Bool {
        gameInstaller.progress.isDownloading
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
    /// Failed resource state lives on the composed sheet view model so that
    /// `abortFailedResources()` resumes the continuation the coordinator is
    /// actually waiting on.
    var failedResources: [FailedModPackResource] {
        get { modPackViewModel.failedResources }
        set { modPackViewModel.failedResources = newValue }
    }

    var failedResourcesContinuation: ((Bool) -> Void)? {
        get { modPackViewModel.failedResourcesContinuation }
        set { modPackViewModel.failedResourcesContinuation = newValue }
    }

    var modPackInstallState: ModPackInstallState {
        modPackViewModel.modPackInstallState
    }
}
