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
        copyCounter: CopyCounter,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?,
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

        await withTaskGroup(of: Void.self) { group in
            for (file, relativePath) in filesToCopy {
                group.addTask {
                    if Task.isCancelled { return }
                    do {
                        try ResourceProcessor.copyToOverrides(
                            file: file,
                            relativePath: relativePath,
                            overridesDir: overridesDir,
                        )

                        let (processed, total) = await copyCounter.increment()
                        let updatedProgress = await progressUpdater.advanceCopyProgress(
                            processed: processed,
                            total: total,
                            currentFile: file.lastPathComponent,
                        )
                        progressCallback?(updatedProgress)
                    } catch {
                        Logger.shared.warning(
                            "复制资源文件失败: \(file.lastPathComponent), 错误: \(error.localizedDescription)",
                        )

                        let (processed, total) = await copyCounter.increment()
                        let updatedProgress = await progressUpdater.advanceCopyProgress(
                            processed: processed,
                            total: total,
                            currentFile: file.lastPathComponent,
                        )
                        progressCallback?(updatedProgress)
                    }
                }
            }

            for await _ in group { }
        }
    }

    /// Builds the manifest file and creates the final archive.
    static func buildIndexAndArchive(
        params: IndexBuildParams,
        tempDir: URL,
        outputPath: URL,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?,
    ) async throws {
        try Task.checkCancellation()
        let rootFileNames = try await writeManifestFile(params: params, tempDir: tempDir)

        let currentProgress = await progressUpdater.getFullProgress()
        progressCallback?(currentProgress)

        try Task.checkCancellation()
        try ModPackArchiver.archive(tempDir: tempDir, outputPath: outputPath, rootFiles: rootFileNames)
    }

    /// Writes the export manifest file (Modrinth or CurseForge) to the temp directory.
    static func writeManifestFile(params: IndexBuildParams, tempDir: URL) async throws -> [String] {
        switch params.exportFormat {
        case .modrinth:
            return try await writeModrinthManifest(params: params, tempDir: tempDir)
        case .curseforge:
            return try await writeCurseForgeManifest(params: params, tempDir: tempDir)
        }
    }
}

extension ModPackExporter {
    /// Tracks scan and copy progress during export.
    actor ProgressUpdater {
        private var scanProgress: ExportProgress.ProgressItem?
        private var copyProgress: ExportProgress.ProgressItem?

        func setCopyProgressTotal(_ total: Int) {
            if let existing = copyProgress {
                copyProgress = ExportProgress.ProgressItem(
                    title: existing.title,
                    progress: existing.progress,
                    currentFile: existing.currentFile,
                    completed: existing.completed,
                    total: total,
                )
            } else {
                copyProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.copying.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: total,
                )
            }
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

    /// Thread-safe counter for processed scan items.
    actor ProcessedCounter {
        private var count = 0

        func increment() -> Int {
            count += 1
            return count
        }
    }

    /// Thread-safe counter for copied files.
    actor CopyCounter {
        private var count = 0
        private let total: Int

        init(total: Int) {
            self.total = total
        }

        func increment() -> (count: Int, total: Int) {
            count += 1
            return (count, total)
        }
    }
}
