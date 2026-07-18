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

    @Published var selectedModPackFile: URL?
    @Published var extractedModPackPath: URL?
    @Published var modPackIndexInfo: ModrinthIndexInfo?
    @Published var isProcessingModPack = false

    let onProcessingStateChanged: (Bool) -> Void
    var gameRepository: GameRepository?

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

    override func performConfirmAction() async {
        startDownloadTask {
            await self.importModPack()
        }
    }

    override func handleCancel() {
        if computeIsDownloading() {
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            modPackViewModel.modPackInstallState.reset()
            isProcessingModPack = false
            onProcessingStateChanged(false)

            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        let extractedPath = extractedModPackPath

        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            if !gameName.isEmpty {
                let profileDir = AppPaths.profileDirectory(gameName: gameName)
                if fm.fileExists(atPath: profileDir.path) {
                    do {
                        try fm.removeItem(at: profileDir)
                        AppLog.modPack.info("Deleted cancelled ModPack game folder: \(profileDir.path)")
                    } catch {
                        AppLog.modPack.error("Failed to delete ModPack game folder: \(error.localizedDescription)")
                    }
                }
            }
            if let path = extractedPath, fm.fileExists(atPath: path.path) {
                do {
                    try fm.removeItem(at: path)
                    AppLog.modPack.info("Deleted ModPack temp extracted files: \(path.path)")
                } catch {
                    AppLog.modPack.error("Failed to delete ModPack temp files: \(error.localizedDescription)")
                }
            }
        }.value

        gameSetupService.downloadState.reset()
        modPackViewModel.modPackInstallState.reset()
        configuration.actions.onCancel()
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
