//
//  ModPackImportViewModel+Import.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackImportViewModel {
    /// Performs the full modpack import flow: runs the install coordinator and handles the result.
    func importModPack() async {
        guard let archiveURL = selectedModPackFile,
              let extractedPath = extractedModPackPath,
              let indexInfo = modPackIndexInfo,
              gameRepository != nil else { return }

        guard CommonUtil.isVersionAtLeast(indexInfo.gameVersion) else {
            return
        }

        isProcessingModPack = false

        let gameName = gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = await modPackViewModel.install(
            archivePath: archiveURL,
            gameName: gameName,
            selectedGameVersion: indexInfo.gameVersion,
            gameInstaller: gameInstaller,
            prepared: .init(
                extractedPath: extractedPath,
                indexInfo: indexInfo,
                projectDetailForIcon: nil,
            ),
        )

        handleModPackInstallationResult(success: success, gameName: gameName)
    }

    /// Handles the final result of a modpack installation.
    ///
    /// Failure and cancellation cleanup (directory removal, error reporting, and
    /// state resets) is owned by `ModPackInstallCoordinator`; only the success
    /// path needs view-level completion here.
    /// - Parameters:
    ///   - success: Whether installation succeeded.
    ///   - gameName: The name of the game being installed.
    func handleModPackInstallationResult(success: Bool, gameName: String) {
        modPackViewModel.clearParsedIndexInfo()
        isProcessingModPack = false

        guard success else { return }

        AppLog.modPack.info("Local modpack import completed: \(gameName)")
        modPackViewModel.modPackInstallState.reset()
        completeInstallation()
    }
}
