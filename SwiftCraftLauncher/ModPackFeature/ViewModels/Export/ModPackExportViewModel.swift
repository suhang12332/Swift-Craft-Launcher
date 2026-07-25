//
//  ModPackExportViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages modpack export state, including format selection, progress tracking, and file handling.
@MainActor
@Observable
class ModPackExportViewModel {
    /// The current state of the export process.
    enum ExportState: Equatable {
        case idle
        case exporting
        case completed
    }

    var exportState: ExportState = .idle
    var exportProgress = ModPackExporter.ExportProgress()
    var modPackName: String = ""
    var modPackVersion: String = "1.0.0"
    var summary: String = ""
    var exportError: String?
    var tempExportPath: URL?
    var selectedFileURLs: [URL] = []
    var currentExportFormat: ModPackExportFormat = .modrinth

    private var exportTask: Task<Void, Never>?
    private var hasShownSaveDialog = false

    var isExporting: Bool {
        exportState == .exporting
    }

    var shouldShowSaveDialog: Bool {
        tempExportPath != nil && !hasShownSaveDialog
    }

    /// Starts the export for the given game asynchronously.
    /// - Parameter gameInfo: The game version to export.
    func startExport(gameInfo: GameVersionInfo) {
        guard exportState == .idle else { return }

        modPackName = gameInfo.gameName

        exportState = .exporting
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(gameInfo.gameName).\(currentExportFormat.fileExtension)")

        exportTask = Task {
            let result = await ModPackExporter.exportModPack(
                gameInfo: gameInfo,
                outputPath: tempPath,
                modPackName: gameInfo.gameName,
                modPackVersion: modPackVersion,
                summary: summary.isEmpty ? nil : summary,
                exportFormat: currentExportFormat,
                selectedFiles: selectedFileURLs,
            ) { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }

            await MainActor.run {
                if Task.isCancelled || result.error is CancellationError || result.message == "Cancelled" {
                    return
                }
                if result.success {
                    self.exportState = .completed
                    self.tempExportPath = result.outputPath
                    AppLog.modPack.info("Modpack exported to temp location successfully: \(result.outputPath?.path ?? "unknown path")")
                } else {
                    self.cleanupTempFile()
                    self.exportState = .idle
                    self.exportError = result.message
                    self.exportProgress = ModPackExporter.ExportProgress()
                    AppLog.modPack.error("Modpack export failed: \(result.message)")
                }
            }
        }
    }

    /// Cancels the current export and cleans up.
    func cancelExport() {
        exportTask?.cancel()
        cleanupTempFile()
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        hasShownSaveDialog = false
    }

    /// Records that the save dialog has been shown.
    func markSaveDialogShown() {
        hasShownSaveDialog = true
    }

    /// Handles a successful save operation and resets state.
    func handleSaveSuccess() {
        cleanupTempFile()
        hasShownSaveDialog = false
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
    }

    /// Handles a save failure and routes the error through the global error handler.
    /// - Parameter error: The error description.
    func handleSaveFailure(error: String) {
        DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
            i18nKey: "error.filesystem.modpack_save_failed",
            level: .silent,
            message: error,
        ))
        cleanupTempFile()
        hasShownSaveDialog = false
    }

    /// Cleans up all export data and resets to the idle state.
    func cleanupAllData() {
        exportTask?.cancel()
        exportTask = nil
        cleanupTempFile()
        cleanupTempDirectories()
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false
        modPackName = ""
        modPackVersion = "1.0.0"
        summary = ""
        currentExportFormat = DIContainer.shared.ui.gameSettingsManager.defaultModPackExportFormat
    }

    /// Resets the view model back to its initial state for the given game.
    /// - Parameter gameInfo: The game version to reset for.
    func resetToInitial(gameInfo: GameVersionInfo) {
        exportTask?.cancel()
        exportTask = nil
        cleanupTempFile()
        cleanupTempDirectories()

        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        tempExportPath = nil
        hasShownSaveDialog = false

        modPackName = gameInfo.gameName
        modPackVersion = "1.0.0"
        summary = ""
        selectedFileURLs = []
    }

    private func cleanupTempFile() {
        guard let tempPath = tempExportPath else { return }
        do {
            if FileManager.default.fileExists(atPath: tempPath.path) {
                try FileManager.default.removeItem(at: tempPath)
                AppLog.modPack.info("Cleaned up temp file: \(tempPath.path)")
            }
        } catch {
            AppLog.modPack.error("Failed to clean up temp file: \(error.localizedDescription)")
        }
        tempExportPath = nil
    }

    private func cleanupTempDirectories() {
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modpack_export")
        guard FileManager.default.fileExists(atPath: exportDir.path) else { return }
        do {
            try FileManager.default.removeItem(at: exportDir)
            AppLog.modPack.info("Cleaned up temp export directory: \(exportDir.path)")
        } catch {
            AppLog.modPack.error("Failed to clean up temp export directory: \(error.localizedDescription)")
        }
    }

    init() {
        currentExportFormat = DIContainer.shared.ui.gameSettingsManager.defaultModPackExportFormat
    }
}
