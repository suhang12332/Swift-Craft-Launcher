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
class ModPackExportViewModel: ObservableObject {
    /// The current state of the export process.
    enum ExportState: Equatable {
        case idle
        case exporting
        case completed
    }

    @Published var exportState: ExportState = .idle
    @Published var exportProgress = ModPackExporter.ExportProgress()
    @Published var modPackName: String = ""
    @Published var modPackVersion: String = "1.0.0"
    @Published var summary: String = ""
    @Published var exportError: String?
    @Published var tempExportPath: URL?
    @Published var saveError: String?
    @Published var selectedFileURLs: [URL] = []
    @Published var currentExportFormat: ModPackExportFormat = .modrinth

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
        saveError = nil

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
        saveError = nil
    }

    /// Records that the save dialog has been shown.
    func markSaveDialogShown() {
        hasShownSaveDialog = true
    }

    /// Handles a successful save operation and resets state.
    func handleSaveSuccess() {
        cleanupTempFile()
        hasShownSaveDialog = false
        saveError = nil
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
    }

    /// Handles a save failure and stores the error message.
    /// - Parameter error: The error description.
    func handleSaveFailure(error: String) {
        saveError = error
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
        saveError = nil
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
        saveError = nil

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
