//
//  SkinToolDetailViewModel+Cleanup.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension SkinToolDetailViewModel {
    /// Resets all selected and cached data, cancels all pending operations, and cleans up temporary files.
    func clearAllData() {
        loadCapeTask?.cancel()
        loadSkinImageTask?.cancel()
        downloadCapeTask?.cancel()
        resetSkinTask?.cancel()
        applyChangesTask?.cancel()

        loadCapeTask = nil
        loadSkinImageTask = nil
        downloadCapeTask = nil
        resetSkinTask = nil
        applyChangesTask = nil

        deleteTemporaryFiles()

        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false

        selectedCapeId = nil
        selectedCapeImageURL = nil
        selectedCapeLocalPath = nil
        selectedCapeImage = nil
        isCapeLoading = false
        capeLoadCompleted = false

        publicSkinInfo = nil
        playerProfile = nil
        currentSkinRenderImage = nil

        currentModel = .classic
        hasChanges = false
        operationInProgress = false

        lastSelectedSkinData = nil
        lastCurrentModel = .classic
        lastSelectedCapeId = nil
        lastCurrentActiveCapeId = nil
    }

    /// Deletes temporary skin and cape files that were written to the system temporary directory.
    func deleteTemporaryFiles() {
        let fileManager = FileManager.default

        if let skinPath = selectedSkinPath, !skinPath.isEmpty {
            let skinURL = URL(fileURLWithPath: skinPath)
            if skinURL.path.hasPrefix(fileManager.temporaryDirectory.path) {
                do {
                    try fileManager.removeItem(at: skinURL)
                    Logger.shared.info("Deleted temporary skin file: \(skinPath)")
                } catch {
                    Logger.shared.warning("Failed to delete temporary skin file: \(error.localizedDescription)")
                }
            }
        }

        if let capePath = selectedCapeLocalPath, !capePath.isEmpty {
            let capeURL = URL(fileURLWithPath: capePath)
            if capeURL.path.hasPrefix(fileManager.temporaryDirectory.path) {
                do {
                    try fileManager.removeItem(at: capeURL)
                } catch {
                    Logger.shared.warning("Failed to delete temporary cape file: \(error.localizedDescription)")
                }
            }
        }
    }
}
