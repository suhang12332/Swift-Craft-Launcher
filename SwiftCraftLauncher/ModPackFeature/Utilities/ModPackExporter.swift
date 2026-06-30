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
        progressCallback: ((ExportProgress) -> Void)? = nil,
    ) async -> ExportResult {
        do {
            try Task.checkCancellation()

            progressCallback?(ExportProgress())

            let (tempDir, overridesDir) = try prepareDirectories()
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            try Task.checkCancellation()

            let resolvedFiles = resolveSelectedFiles(from: selectedFiles)
            let gameDirectory = AppPaths.profileDirectory(gameName: gameInfo.gameName)
            let shouldScan: (URL) -> Bool = switch exportFormat {
            case .modrinth:
                { shouldScanForModrinth($0, gameDirectory: gameDirectory) }
            case .curseforge:
                { shouldScanForCurseForge($0, gameDirectory: gameDirectory) }
            }
            let totalScanResources = resolvedFiles.filter(shouldScan).count
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
                gameInfo: gameInfo,
                selectedFiles: resolvedFiles,
                totalResources: totalScanResources,
                exportFormat: exportFormat,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback,
            )

            try Task.checkCancellation()

            let copyCounter = CopyCounter(total: selectedResourcesResult.filesToCopy.count)

            try await copyFiles(
                params: CopyFilesParams(
                    filesToCopy: selectedResourcesResult.filesToCopy,
                    overridesDir: overridesDir,
                ),
                copyCounter: copyCounter,
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
                    indexFiles: selectedResourcesResult.indexFiles,
                    curseForgeFiles: selectedResourcesResult.curseForgeFiles,
                    curseForgeModListItems: selectedResourcesResult.curseForgeModListItems,
                    exportFormat: exportFormat,
                ),
                tempDir: tempDir,
                outputPath: outputPath,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback,
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
                    message: "已取消",
                )
            }
            Logger.shared.error("导出整合包失败: \(error.localizedDescription)")
            return ExportResult(
                success: false,
                outputPath: nil,
                error: error,
                message: "导出失败: \(error.localizedDescription)",
            )
        }
    }

    static func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modpack_export")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    struct IndexBuildParams {
        let gameInfo: GameVersionInfo
        let modPackName: String
        let modPackVersion: String
        let summary: String?
        let indexFiles: [ModrinthIndexFile]
        let curseForgeFiles: [CurseForgeManifestBuilder.ManifestFile]
        let curseForgeModListItems: [CurseForgeModListItem]
        let exportFormat: ModPackExportFormat
    }

    struct CurseForgeModListItem {
        let projectID: Int
        let fileID: Int
        let fileName: String
        let projectName: String?
        let authorsText: String?
    }

    struct SelectedResourcesResult {
        let indexFiles: [ModrinthIndexFile]
        let curseForgeFiles: [CurseForgeManifestBuilder.ManifestFile]
        let curseForgeModListItems: [CurseForgeModListItem]
        let filesToCopy: [(file: URL, relativePath: String)]
    }

    struct CopyFilesParams {
        let filesToCopy: [(file: URL, relativePath: String)]
        let overridesDir: URL
    }
}
