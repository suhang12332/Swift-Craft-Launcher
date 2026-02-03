//
//  ModPackExporter.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation

/// 整合包导出器
/// 将游戏实例导出为 Modrinth 官方整合包格式 (.mrpack)
enum ModPackExporter {

    // MARK: - Export Result

    struct ExportResult {
        let success: Bool
        let outputPath: URL?
        let error: Error?
        let message: String
    }

    // MARK: - Export Progress

    struct ExportProgress {
        var progress: Double = 0.0
        var totalFiles: Int = 0
        var processedFiles: Int = 0

        // 多个进度条支持
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

    // MARK: - Main Export Function

    /// 导出整合包
    /// - Parameters:
    ///   - gameInfo: 游戏实例信息
    ///   - outputPath: 输出文件路径
    ///   - modPackName: 整合包名称
    ///   - modPackVersion: 整合包版本
    ///   - summary: 整合包描述（可选）
    ///   - progressCallback: 进度回调
    /// - Returns: 导出结果
    static func exportModPack(
        gameInfo: GameVersionInfo,
        outputPath: URL,
        modPackName: String,
        modPackVersion: String = "1.0.0",
        summary: String? = nil,
        progressCallback: ((ExportProgress) -> Void)? = nil
    ) async -> ExportResult {
        var progress = ExportProgress()

        do {
            // 1. 准备临时目录
            progress.progress = 0.0
            progressCallback?(progress)

            let (tempDir, overridesDir) = try prepareDirectories()
            defer {
                // 清理临时目录
                try? FileManager.default.removeItem(at: tempDir)
            }

            // 2. 先显示扫描进度条（在开始扫描之前）
            progress.progress = 0.1
            progress.scanProgress = ExportProgress.ProgressItem(
                title: "modpack.export.scanning.title".localized(),
                progress: 0.0,
                currentFile: "",
                completed: 0,
                total: 1
            )
            progressCallback?(progress)

            // 给UI一点时间渲染，确保进度条先显示出来
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // 3. 扫描所有资源文件
            let scanResults = try ResourceScanner.scanAllResources(gameInfo: gameInfo)
            let totalResources = ResourceScanner.totalFileCount(scanResults)
            let totalConfigFiles = try ConfigFileCopier.countFiles(gameInfo: gameInfo)
            let totalFiles = totalResources + totalConfigFiles
            progress.totalFiles = totalFiles

            // 4. 更新扫描进度条为实际值
            var initialProgress = progress
            initialProgress.scanProgress = ExportProgress.ProgressItem(
                title: "modpack.export.scanning.title".localized(),
                progress: totalResources > 0 ? 0.0 : 1.0,
                currentFile: "",
                completed: 0,
                total: max(totalResources, 1)
            )
            progressCallback?(initialProgress)

            // 给UI一点时间渲染
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            // 5. 扫描识别所有资源文件
            progress.progress = 0.2
            progressCallback?(progress)

            let progressUpdater = ProgressUpdater(baseProgress: initialProgress)
            let processedCounter = ProcessedCounter()

            let (indexFiles, filesToCopy) = await scanAndIdentifyResources(
                gameInfo: gameInfo,
                scanResults: scanResults,
                totalResources: totalResources,
                progressUpdater: progressUpdater,
                processedCounter: processedCounter,
                progressCallback: progressCallback
            )

            // 6. 复制需要复制的资源文件和配置文件
            progress.progress = 0.6
            progressCallback?(progress)

            let copyCounter = CopyCounter(total: filesToCopy.count + totalConfigFiles)

            try await copyFiles(
                params: CopyFilesParams(
                    filesToCopy: filesToCopy,
                    gameInfo: gameInfo,
                    overridesDir: overridesDir,
                    totalConfigFiles: totalConfigFiles
                ),
                copyCounter: copyCounter,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback
            )

            // 7. 生成索引文件并打包
            try await buildIndexAndArchive(
                params: IndexBuildParams(
                    gameInfo: gameInfo,
                    modPackName: modPackName,
                    modPackVersion: modPackVersion,
                    summary: summary,
                    indexFiles: indexFiles
                ),
                tempDir: tempDir,
                outputPath: outputPath,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback
            )

            return ExportResult(
                success: true,
                outputPath: outputPath,
                error: nil,
                message: ""
            )
        } catch {
            Logger.shared.error("导出整合包失败: \(error.localizedDescription)")
            return ExportResult(
                success: false,
                outputPath: nil,
                error: error,
                message: "导出失败: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helper Functions

    /// 创建临时目录
    private static func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("modpack_export")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    // MARK: - Parameter Structures

    /// 索引构建参数
    private struct IndexBuildParams {
        let gameInfo: GameVersionInfo
        let modPackName: String
        let modPackVersion: String
        let summary: String?
        let indexFiles: [ModrinthIndexFile]
    }

    /// 文件复制参数
    private struct CopyFilesParams {
        let filesToCopy: [(file: URL, resourceType: ResourceScanner.ResourceType)]
        let gameInfo: GameVersionInfo
        let overridesDir: URL
        let totalConfigFiles: Int
    }

    /// 准备临时目录和 overrides 目录结构
    private static func prepareDirectories() throws -> (tempDir: URL, overridesDir: URL) {
        let tempDir = try createTempDirectory()
        let overridesDir = tempDir.appendingPathComponent("overrides")
        try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)

        // 创建各种资源的 overrides 子目录
        for resourceType in ResourceScanner.ResourceType.allCases {
            let subDir = overridesDir.appendingPathComponent(resourceType.rawValue)
            try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        }

        return (tempDir, overridesDir)
    }

    /// 扫描并识别所有资源文件
    private static func scanAndIdentifyResources(
        gameInfo: GameVersionInfo,
        scanResults: [ResourceScanner.ResourceType: [URL]],
        totalResources: Int,
        progressUpdater: ProgressUpdater,
        processedCounter: ProcessedCounter,
        progressCallback: ((ExportProgress) -> Void)?
    ) async -> ([ModrinthIndexFile], [(file: URL, resourceType: ResourceScanner.ResourceType)]) {
        return await withTaskGroup(of: ResourceProcessor.ProcessResult.self) { group in
            for (resourceType, files) in scanResults {
                for file in files {
                    group.addTask {
                        // 只识别，不复制
                        let result = await ResourceProcessor.identify(
                            file: file,
                            resourceType: resourceType
                        )

                        // 更新扫描进度
                        let processed = await processedCounter.increment()
                        let scanTotal = max(totalResources, 1) // 至少为1，避免除零错误
                        let scanItem = ExportProgress.ProgressItem(
                            title: "modpack.export.scanning.title".localized(),
                            progress: Double(processed) / Double(scanTotal),
                            currentFile: result.sourceFile.lastPathComponent,
                            completed: processed,
                            total: scanTotal
                        )
                        await progressUpdater.updateScanProgress(scanItem)

                        // 获取完整进度并更新
                        let updatedProgress = await progressUpdater.getFullProgress()
                        progressCallback?(updatedProgress)

                        return result
                    }
                }
            }

            // 收集所有结果
            var indexFiles: [ModrinthIndexFile] = []
            var filesToCopy: [(file: URL, resourceType: ResourceScanner.ResourceType)] = []

            for await result in group {
                if let indexFile = result.indexFile {
                    // 成功识别到 Modrinth 资源，添加到索引
                    indexFiles.append(indexFile)
                } else {
                    // 未识别到或识别失败，需要复制到 overrides
                    if result.shouldCopyToOverrides {
                        if let resourceType = ResourceScanner.ResourceType(rawValue: result.relativePath) {
                            filesToCopy.append((file: result.sourceFile, resourceType: resourceType))
                        } else {
                            Logger.shared.warning("无法识别资源类型: \(result.relativePath)")
                        }
                    } else {
                        // 这种情况理论上不应该发生，但记录警告以防万一
                        Logger.shared.warning("资源文件既没有索引文件也不需要复制: \(result.sourceFile.lastPathComponent)")
                    }
                }
            }

            // 如果没有资源文件，确保扫描进度条显示为完成
            if totalResources == 0 {
                let completedScanItem = ExportProgress.ProgressItem(
                    title: "modpack.export.scanning.title".localized(),
                    progress: 1.0,
                    currentFile: "",
                    completed: 0,
                    total: 1
                )
                await progressUpdater.updateScanProgress(completedScanItem)
                let updatedProgress = await progressUpdater.getFullProgress()
                progressCallback?(updatedProgress)
            }

            return (indexFiles, filesToCopy)
        }
    }

    /// 复制资源文件和配置文件
    private static func copyFiles(
        params: CopyFilesParams,
        copyCounter: CopyCounter,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?
    ) async throws {
        let filesToCopy = params.filesToCopy
        let gameInfo = params.gameInfo
        let overridesDir = params.overridesDir
        let totalConfigFiles = params.totalConfigFiles
        let totalFilesToCopy = filesToCopy.count + totalConfigFiles

        // 更新复制进度条的总数
        if totalFilesToCopy > 0 {
            await progressUpdater.setCopyProgressTotal(totalFilesToCopy)
            let currentProgress = await progressUpdater.getFullProgress()
            progressCallback?(currentProgress)
        }

        // 并发复制资源文件和配置文件
        async let copyResourcesTask: Void = {
            await withTaskGroup(of: Void.self) { group in
                for (file, resourceType) in filesToCopy {
                    group.addTask {
                        do {
                            try ResourceProcessor.copyToOverrides(
                                file: file,
                                resourceType: resourceType,
                                overridesDir: overridesDir
                            )

                            // 更新复制进度
                            let (processed, total) = await copyCounter.increment()
                            let copyItem = ExportProgress.ProgressItem(
                                title: "modpack.export.copying.title".localized(),
                                progress: Double(processed) / Double(max(total, 1)),
                                currentFile: file.lastPathComponent,
                                completed: processed,
                                total: total
                            )
                            await progressUpdater.updateCopyProgress(copyItem)

                            // 获取完整进度并更新
                            let updatedProgress = await progressUpdater.getFullProgress()
                            progressCallback?(updatedProgress)
                        } catch {
                            Logger.shared.warning("复制资源文件失败: \(file.lastPathComponent), 错误: \(error.localizedDescription)")

                            // 更新进度（即使失败也计入已处理）
                            let (processed, total) = await copyCounter.increment()
                            let copyItem = ExportProgress.ProgressItem(
                                title: "modpack.export.copying.title".localized(),
                                progress: Double(processed) / Double(max(total, 1)),
                                currentFile: file.lastPathComponent,
                                completed: processed,
                                total: total
                            )
                            await progressUpdater.updateCopyProgress(copyItem)

                            // 获取完整进度并更新
                            let updatedProgress = await progressUpdater.getFullProgress()
                            progressCallback?(updatedProgress)
                        }
                    }
                }

                // 等待所有复制任务完成
                for await _ in group {}
            }
        }()

        async let copyConfigTask: Void = {
            try await ConfigFileCopier.copyFiles(
                gameInfo: gameInfo,
                to: overridesDir
            ) { _, currentFileName in
                Task {
                    // 使用共享计数器更新总进度
                    let (processed, total) = await copyCounter.increment()
                    let copyItem = ExportProgress.ProgressItem(
                        title: "modpack.export.copying.title".localized(),
                        progress: Double(processed) / Double(max(total, 1)),
                        currentFile: currentFileName,
                        completed: processed,
                        total: total
                    )
                    await progressUpdater.updateCopyProgress(copyItem)

                    // 获取完整进度并更新
                    let updatedProgress = await progressUpdater.getFullProgress()
                    progressCallback?(updatedProgress)
                }
            }
        }()

        // 等待两个复制任务完成
        await copyResourcesTask
        try await copyConfigTask
    }

    /// 生成索引文件并打包
    private static func buildIndexAndArchive(
        params: IndexBuildParams,
        tempDir: URL,
        outputPath: URL,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?
    ) async throws {
        // 生成 modrinth.index.json
        var currentProgress = await progressUpdater.getFullProgress()
        currentProgress.progress = 0.9
        progressCallback?(currentProgress)

        let indexJson = try await ModrinthIndexBuilder.build(
            gameInfo: params.gameInfo,
            modPackName: params.modPackName,
            modPackVersion: params.modPackVersion,
            summary: params.summary,
            files: params.indexFiles
        )

        let indexPath = tempDir.appendingPathComponent(AppConstants.modrinthIndexFileName)
        try indexJson.write(to: indexPath, atomically: true, encoding: String.Encoding.utf8)

        // 打包为 .mrpack
        currentProgress = await progressUpdater.getFullProgress()
        currentProgress.progress = 0.95
        progressCallback?(currentProgress)

        try ModPackArchiver.archive(tempDir: tempDir, outputPath: outputPath)

        // 打包完成，确保进度条显示100%
        currentProgress = await progressUpdater.getFullProgress()
        currentProgress.progress = 1.0
        // 确保扫描和复制进度条都显示100%，但保留最后一个处理的文件名
        if var scanProgress = currentProgress.scanProgress {
            scanProgress.progress = 1.0
            scanProgress.completed = scanProgress.total
            currentProgress.scanProgress = scanProgress
        }
        if var copyProgress = currentProgress.copyProgress {
            copyProgress.progress = 1.0
            copyProgress.completed = copyProgress.total
            currentProgress.copyProgress = copyProgress
        }
        progressCallback?(currentProgress)
    }

    // MARK: - Progress Management Types

    /// 进度更新器
    private actor ProgressUpdater {
        private var scanProgress: ExportProgress.ProgressItem?
        private var copyProgress: ExportProgress.ProgressItem?
        private var baseProgress: ExportProgress

        init(baseProgress: ExportProgress) {
            self.baseProgress = baseProgress
        }

        func updateScanProgress(_ item: ExportProgress.ProgressItem) {
            scanProgress = item
        }

        func updateCopyProgress(_ item: ExportProgress.ProgressItem) {
            copyProgress = item
        }

        func setCopyProgressTotal(_ total: Int) {
            if let existing = copyProgress {
                copyProgress = ExportProgress.ProgressItem(
                    title: existing.title,
                    progress: existing.progress,
                    currentFile: existing.currentFile,
                    completed: existing.completed,
                    total: total
                )
            } else {
                copyProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.copying.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: total
                )
            }
        }

        func getFullProgress() -> ExportProgress {
            var fullProgress = baseProgress
            fullProgress.scanProgress = scanProgress
            fullProgress.copyProgress = copyProgress
            return fullProgress
        }
    }

    /// 已处理文件计数器
    private actor ProcessedCounter {
        private var count = 0

        func increment() -> Int {
            count += 1
            return count
        }

        func reset() {
            count = 0
        }
    }

    /// 复制进度计数器
    private actor CopyCounter {
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
