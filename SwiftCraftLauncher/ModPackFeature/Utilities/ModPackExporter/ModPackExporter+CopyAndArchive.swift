//
//  ModPackExporter+CopyAndArchive.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackExporter {
    /// Copies selected resource files to the overrides directory during export.
    static func copyFiles(
        params: CopyFilesParams,
        progressUpdater: ProgressUpdater,
        progressCallback: (@Sendable (ExportProgress) -> Void)?,
    ) async throws {
        try Task.checkCancellation()

        let filesToCopy = params.filesToCopy
        let overridesDir = params.overridesDir
        let totalFilesToCopy = filesToCopy.count

        if totalFilesToCopy > 0 {
            await progressUpdater.setCopyProgressTotal(totalFilesToCopy)
            let updatedProgress = await progressUpdater.getFullProgress()
            progressCallback?(updatedProgress)
        }

        let processedCounter = ProcessedCounter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: maxConcurrentExportOperations)

            for (file, relativePath) in filesToCopy {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    try Task.checkCancellation()

                    try ResourceProcessor.copyToOverrides(
                        file: file,
                        relativePath: relativePath,
                        overridesDir: overridesDir,
                    )

                    let processed = await processedCounter.increment()
                    let updatedProgress = await progressUpdater.advanceCopyProgress(
                        processed: processed,
                        total: totalFilesToCopy,
                        currentFile: file.lastPathComponent,
                    )
                    progressCallback?(updatedProgress)
                }
            }

            try await group.waitForAll()
        }
    }

    /// Builds the manifest file and creates the final archive.
    static func buildIndexAndArchive(
        params: IndexBuildParams,
        tempDir: URL,
        outputPath: URL,
    ) async throws {
        try Task.checkCancellation()
        let rootFileNames = try await writeManifestFile(params: params, tempDir: tempDir)

        try Task.checkCancellation()
        try ModPackArchiver.archive(tempDir: tempDir, outputPath: outputPath, rootFiles: rootFileNames)
    }

    /// Writes the export manifest file (Modrinth or CurseForge) to the temp directory.
    static func writeManifestFile(params: IndexBuildParams, tempDir: URL) async throws -> [String] {
        switch params.manifest {
        case let .modrinth(files):
            return try await writeModrinthManifest(
                params: params,
                files: files,
                tempDir: tempDir,
            )
        case let .curseForge(files, modListItems):
            return try await writeCurseForgeManifest(
                params: params,
                files: files,
                modListItems: modListItems,
                tempDir: tempDir,
            )
        }
    }
}

extension ModPackExporter {
    /// Tracks scan and copy progress during export.
    actor ProgressUpdater {
        private var scanProgress: ExportProgress.ProgressItem?
        private var copyProgress: ExportProgress.ProgressItem?

        func setCopyProgressTotal(_ total: Int) {
            copyProgress = ExportProgress.ProgressItem(
                title: "modpack.export.copying.title".localized(),
                progress: 0.0,
                currentFile: "",
                completed: 0,
                total: total,
            )
        }

        func advanceScanProgress(
            processed: Int,
            total: Int,
            currentFile: String,
        ) -> ExportProgress {
            let safeTotal = max(total, 1)
            let scanItem = ExportProgress.ProgressItem(
                title: "modpack.export.scanning.title".localized(),
                progress: Double(processed) / Double(safeTotal),
                currentFile: currentFile,
                completed: processed,
                total: safeTotal,
            )
            scanProgress = scanItem
            return getFullProgress()
        }

        func advanceCopyProgress(
            processed: Int,
            total: Int,
            currentFile: String,
        ) -> ExportProgress {
            let safeTotal = max(total, 1)
            let copyItem = ExportProgress.ProgressItem(
                title: "modpack.export.copying.title".localized(),
                progress: Double(processed) / Double(safeTotal),
                currentFile: currentFile,
                completed: processed,
                total: safeTotal,
            )
            copyProgress = copyItem
            return getFullProgress()
        }

        func getFullProgress() -> ExportProgress {
            ExportProgress(
                scanProgress: scanProgress,
                copyProgress: copyProgress,
            )
        }
    }

    /// Thread-safe counter for processed scan and copy items.
    actor ProcessedCounter {
        private var count = 0

        func increment() -> Int {
            count += 1
            return count
        }
    }
}
