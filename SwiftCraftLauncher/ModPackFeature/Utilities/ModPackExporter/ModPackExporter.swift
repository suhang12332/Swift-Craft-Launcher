//
//  ModPackExporter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Exports a game instance as a Modpack (.mrpack) or CurseForge archive.
enum ModPackExporter {
    struct ExportResult {
        let success: Bool
        let outputPath: URL?
        let error: Error?
        let message: String
    }

    struct ExportProgress {
        struct ProgressItem {
            var title: String
            var progress: Double
            var currentFile: String
            var completed: Int
            var total: Int
        }

        var scanProgress: ProgressItem?
        var copyProgress: ProgressItem?
    }

    static func exportModPack(
        gameInfo: GameVersionInfo,
        outputPath: URL,
        modPackName: String,
        modPackVersion: String = "1.0.0",
        summary: String? = nil,
        exportFormat: ModPackExportFormat = .modrinth,
        selectedFiles: [URL],
        progressCallback: (@Sendable (ExportProgress) -> Void)? = nil,
    ) async -> ExportResult {
        do {
            try Task.checkCancellation()

            // The identifier cache is only useful for the duration of one export.
            // Clearing it afterwards prevents memory from growing across exports.
            defer {
                Task { await ModrinthResourceIdentifier.clearCache() }
            }

            let (tempDir, overridesDir) = try prepareDirectories()
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            try Task.checkCancellation()

            let resolvedFiles = resolveSelectedFiles(from: selectedFiles)
            let gameDirectory = AppPaths.profileDirectory(gameName: gameInfo.gameName)

            // Only the four resource folders participate in scanning. Every other
            // selected file is copied to overrides and must not affect scan totals.
            var filesToScan: [URL] = []
            var filesOutsideScanScope: [URL] = []
            for file in resolvedFiles {
                if shouldScanResource(file, gameDirectory: gameDirectory) {
                    filesToScan.append(file)
                } else {
                    filesOutsideScanScope.append(file)
                }
            }
            let totalScanResources = filesToScan.count
            var initialProgress = ExportProgress()
            if totalScanResources > 0 {
                initialProgress.scanProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.scanning.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: totalScanResources,
                )
            }
            progressCallback?(initialProgress)

            let progressUpdater = ProgressUpdater()

            let selectedResourcesResult = await identifySelectedResources(
                gameDirectory: gameDirectory,
                filesToScan: filesToScan,
                filesOutsideScanScope: filesOutsideScanScope,
                exportFormat: exportFormat,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback,
            )

            try Task.checkCancellation()

            try await copyFiles(
                params: CopyFilesParams(
                    filesToCopy: selectedResourcesResult.filesToCopy,
                    overridesDir: overridesDir,
                ),
                progressUpdater: progressUpdater,
                progressCallback: progressCallback,
            )

            try Task.checkCancellation()

            try await buildIndexAndArchive(
                params: IndexBuildParams(
                    gameInfo: gameInfo,
                    modPackName: modPackName,
                    modPackVersion: modPackVersion,
                    summary: summary,
                    manifest: selectedResourcesResult.manifest,
                ),
                tempDir: tempDir,
                outputPath: outputPath,
            )

            return ExportResult(
                success: true,
                outputPath: outputPath,
                error: nil,
                message: "",
            )
        } catch {
            if error is CancellationError {
                return ExportResult(
                    success: false,
                    outputPath: nil,
                    error: error,
                    message: "Cancelled",
                )
            }
            AppLog.modPack.error("Failed to export modpack: \(error.localizedDescription)")
            return ExportResult(
                success: false,
                outputPath: nil,
                error: error,
                message: "Export failed: \(error.localizedDescription)",
            )
        }
    }

    static func createTempDirectory() throws -> URL {
        try TemporaryDirectory(purpose: .modpackExport).url
    }

    enum ModPackManifestData {
        case modrinth([ModrinthIndexFile])
        case curseForge(
            files: [CurseForgeManifestBuilder.ManifestFile],
            modListItems: [CurseForgeModListItem],
        )
    }

    struct IndexBuildParams {
        let gameInfo: GameVersionInfo
        let modPackName: String
        let modPackVersion: String
        let summary: String?
        let manifest: ModPackManifestData
    }

    struct CurseForgeModListItem {
        let projectID: Int
        let fileName: String
    }

    struct SelectedResourcesResult {
        let manifest: ModPackManifestData
        let filesToCopy: [(file: URL, relativePath: String)]
    }

    struct CopyFilesParams {
        let filesToCopy: [(file: URL, relativePath: String)]
        let overridesDir: URL
    }

    /// Caps concurrent export work so memory and thread usage stay predictable.
    static let maxConcurrentExportOperations = 8
}
