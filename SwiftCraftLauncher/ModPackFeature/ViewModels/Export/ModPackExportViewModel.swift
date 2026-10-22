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
    var modPackVersion: String = "1.0.0"
    var summary: String = ""
    var exportError: String?
    var tempExportPath: URL?
    var selectedFileURLs: [URL] = []
    var currentExportFormat: ModPackExportFormat = .modrinth

    private var exportTask: Task<Void, Never>?
    private var exportRunID = UUID()
    private var hasShownSaveDialog = false

    var isExporting: Bool {
        exportState == .exporting
    }

    var completedExportPath: URL? {
        exportState == .completed ? tempExportPath : nil
    }

    var shouldShowSaveDialog: Bool {
        completedExportPath != nil && !hasShownSaveDialog
    }

    /// Starts the export for the given game asynchronously.
    /// - Parameter gameInfo: The game version to export.
    func startExport(gameInfo: GameVersionInfo) {
        guard exportState == .idle else { return }

        cleanupTempFile()

        let runID = UUID()
        exportRunID = runID

        exportState = .exporting
        exportProgress = ModPackExporter.ExportProgress()
        exportError = nil
        hasShownSaveDialog = false

        let runDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("modpack_export")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)

        let tempPath = runDirectory
            .appendingPathComponent("\(gameInfo.gameName).\(currentExportFormat.fileExtension)")

        tempExportPath = tempPath

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
                    guard self.exportRunID == runID else { return }
                    self.exportProgress = progress
                }
            }

            await MainActor.run {
                guard self.exportRunID == runID else { return }
                if Task.isCancelled || result.error is CancellationError {
                    return
                }
                if result.success {
                    self.exportState = .completed
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

    /// Cancels the current export and removes all transient export state.
    /// Form values such as version, summary, format, and file selection are kept.
    func cancelExport() {
        exportRunID = UUID()
        exportTask?.cancel()
        exportTask = nil
        finishSaving(error: nil)
    }

    /// Records that the save dialog has been shown.
    func markSaveDialogShown() {
        hasShownSaveDialog = true
    }

    /// Handles a successful save operation and resets state.
    func handleSaveSuccess() {
        finishSaving(error: nil)
    }

    /// Handles a save failure and routes the error through the global error handler.
    /// - Parameter error: The error description.
    func handleSaveFailure(error: String) {
        DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
            i18nKey: "error.filesystem.modpack_save_failed",
            level: .silent,
            message: error,
        ))
        finishSaving(error: error)
    }

    /// Handles a save cancellation by discarding the prepared archive so the
    /// next Export action starts a fresh export.
    func handleSaveCancellation() {
        finishSaving(error: nil)
    }

    private func finishSaving(error: String?) {
        cleanupTempFile()
        hasShownSaveDialog = false
        exportState = .idle
        exportProgress = ModPackExporter.ExportProgress()
        exportError = error
    }

    /// Cleans up all export data and resets to the idle state.
    func cleanupAllData() {
        resetExportState(resetFormat: true)
    }

    private func resetExportState(resetFormat: Bool) {
        cancelExport()
        modPackVersion = "1.0.0"
        summary = ""
        selectedFileURLs = []
        if resetFormat {
            currentExportFormat = DIContainer.shared.ui.gameSettingsManager.defaultModPackExportFormat
        }
    }

    private func cleanupTempFile() {
        guard let tempPath = tempExportPath else { return }

        let fileManager = FileManager.default
        let runDirectory = tempPath.deletingLastPathComponent()

        if fileManager.fileExists(atPath: tempPath.path) {
            do {
                try fileManager.removeItem(at: tempPath)
                AppLog.modPack.info("Cleaned up temp file: \(tempPath.path)")
            } catch {
                AppLog.modPack.error("Failed to clean up temp file: \(error.localizedDescription)")
            }
        }

        if fileManager.fileExists(atPath: runDirectory.path) {
            do {
                try fileManager.removeItem(at: runDirectory)
                AppLog.modPack.info("Cleaned up temp export directory: \(runDirectory.path)")
            } catch {
                AppLog.modPack.error("Failed to clean up temp export directory: \(error.localizedDescription)")
            }
        }

        tempExportPath = nil
    }

    init() {
        currentExportFormat = DIContainer.shared.ui.gameSettingsManager.defaultModPackExportFormat
    }
}
