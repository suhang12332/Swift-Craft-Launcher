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
        isApplyingChanges = false
        isResettingSkin = false

        lastSelectedSkinData = nil
        lastCurrentModel = .classic
        lastSelectedCapeId = nil
        lastCurrentActiveCapeId = nil
    }

    /// Deletes temporary skin and cape files that were written to the system temporary directory.
    func deleteTemporaryFiles() {
        deleteTemporarySkinFile()
        deleteTemporaryCapeFile()
    }

    /// Deletes the selected skin's temporary file, if it is a temporary file.
    func deleteTemporarySkinFile() {
        guard let skinPath = selectedSkinPath, !skinPath.isEmpty else { return }
        let skinURL = URL(fileURLWithPath: skinPath)
        guard TemporaryFile.isTemporary(skinURL) else { return }

        do {
            try FileManager.default.removeItem(at: skinURL)
            AppLog.player.info("Deleted temporary skin file: \(skinPath)")
        } catch {
            AppLog.player.error("Failed to delete temporary skin file: \(error.localizedDescription)")
        }
    }

    /// Deletes the selected cape's temporary file, if it is a temporary file.
    func deleteTemporaryCapeFile() {
        guard let capePath = selectedCapeLocalPath, !capePath.isEmpty else { return }
        let capeURL = URL(fileURLWithPath: capePath)
        guard TemporaryFile.isTemporary(capeURL) else { return }

        do {
            try FileManager.default.removeItem(at: capeURL)
        } catch {
            AppLog.player.error("Failed to delete temporary cape file: \(error.localizedDescription)")
        }
    }
}
