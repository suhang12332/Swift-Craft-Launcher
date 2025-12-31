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
            
            let tempDir = try createTempDirectory()
            defer {
                // 清理临时目录
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            // 创建 overrides 目录结构
            let overridesDir = tempDir.appendingPathComponent("overrides")
            try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)
            
            // 创建各种资源的 overrides 子目录
            for resourceType in ResourceScanner.ResourceType.allCases {
                let subDir = overridesDir.appendingPathComponent(resourceType.rawValue)
                try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
            }
            
            // 2. 扫描所有资源文件
            progress.progress = 0.1
            progressCallback?(progress)
            
            let scanResults = try ResourceScanner.scanAllResources(gameInfo: gameInfo)
            let totalResources = ResourceScanner.totalFileCount(scanResults)
            let totalConfigFiles = try ConfigFileCopier.countFiles(gameInfo: gameInfo)
            let totalFiles = totalResources + totalConfigFiles
            progress.totalFiles = totalFiles
            
            // 3. 初始化进度条
            var initialProgress = progress
            if totalResources > 0 {
                initialProgress.scanProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.scanning.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: totalResources
                )
            }
            
            if totalConfigFiles > 0 {
                initialProgress.copyProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.copying.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: totalConfigFiles
                )
            }
            progressCallback?(initialProgress)
            
            // 给UI一点时间渲染
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            // 4. 并发处理资源文件和配置文件
            progress.progress = 0.2
            progressCallback?(progress)
            
            // 创建进度更新器
            actor ProgressUpdater {
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
                
                func getFullProgress() -> ExportProgress {
                    var fullProgress = baseProgress
                    fullProgress.scanProgress = scanProgress
                    fullProgress.copyProgress = copyProgress
                    return fullProgress
                }
            }
            
            let progressUpdater = ProgressUpdater(baseProgress: initialProgress)
            
            // 使用 actor 计数器跟踪已处理文件数
            actor ProcessedCounter {
                private var count = 0
                
                func increment() -> Int {
                    count += 1
                    return count
                }
            }
            
            let processedCounter = ProcessedCounter()
            
            // 并发执行：处理资源文件和复制配置文件
            async let processResourcesTask: [ModrinthIndexFile] = {
                await withTaskGroup(of: ModrinthIndexFile?.self) { group in
                    for (resourceType, files) in scanResults {
                        for file in files {
                            group.addTask {
                                do {
                                    let result = try await ResourceProcessor.process(
                                        file: file,
                                        resourceType: resourceType,
                                        overridesDir: overridesDir
                                    )
                                    
                                    // 更新扫描进度
                                    let processed = await processedCounter.increment()
                                    let scanItem = ExportProgress.ProgressItem(
                                        title: "modpack.export.scanning.title".localized(),
                                        progress: Double(processed) / Double(max(totalResources, 1)),
                                        currentFile: result.sourceFile.lastPathComponent,
                                        completed: processed,
                                        total: totalResources
                                    )
                                    await progressUpdater.updateScanProgress(scanItem)
                                    
                                    // 获取完整进度并更新
                                    let updatedProgress = await progressUpdater.getFullProgress()
                                    progressCallback?(updatedProgress)
                                    
                                    return result.indexFile
                                } catch {
                                    // 处理失败，记录错误但继续处理其他文件
                                    Logger.shared.warning("处理资源文件失败: \(file.lastPathComponent), 错误: \(error.localizedDescription)")
                                    
                                    // 更新进度（即使失败也计入已处理）
                                    let processed = await processedCounter.increment()
                                    let scanItem = ExportProgress.ProgressItem(
                                        title: "modpack.export.scanning.title".localized(),
                                        progress: Double(processed) / Double(max(totalResources, 1)),
                                        currentFile: file.lastPathComponent,
                                        completed: processed,
                                        total: totalResources
                                    )
                                    await progressUpdater.updateScanProgress(scanItem)
                                    
                                    // 获取完整进度并更新
                                    let updatedProgress = await progressUpdater.getFullProgress()
                                    progressCallback?(updatedProgress)
                                    
                                    return nil
                                }
                            }
                        }
                    }
                    
                    // 收集所有索引文件
                    var indexFiles: [ModrinthIndexFile] = []
                    for await indexFile in group {
                        if let indexFile = indexFile {
                            indexFiles.append(indexFile)
                        }
                    }
                    return indexFiles
                }
            }()
            
            async let copyConfigTask: Void = {
                try await ConfigFileCopier.copyFiles(
                    gameInfo: gameInfo,
                    to: overridesDir
                ) { count, currentFileName in
                    Task {
                        let copyItem = ExportProgress.ProgressItem(
                            title: "modpack.export.copying.title".localized(),
                            progress: Double(count) / Double(max(totalConfigFiles, 1)),
                            currentFile: currentFileName,
                            completed: count,
                            total: totalConfigFiles
                        )
                        await progressUpdater.updateCopyProgress(copyItem)
                        
                        // 获取完整进度并更新
                        let updatedProgress = await progressUpdater.getFullProgress()
                        progressCallback?(updatedProgress)
                    }
                }
            }()
            
            // 等待两个任务完成
            let indexFiles = await processResourcesTask
            try await copyConfigTask
            
            // 5. 生成 modrinth.index.json
            // 从进度更新器获取最新的进度数据（包含进度条信息）
            var currentProgress = await progressUpdater.getFullProgress()
            currentProgress.progress = 0.9
            // 保持进度条数据，确保在打包过程中进度条仍然显示
            progressCallback?(currentProgress)
            
            let indexJson = try await ModrinthIndexBuilder.build(
                gameInfo: gameInfo,
                modPackName: modPackName,
                modPackVersion: modPackVersion,
                summary: summary,
                files: indexFiles
            )
            
            let indexPath = tempDir.appendingPathComponent(AppConstants.modrinthIndexFileName)
            try indexJson.write(to: indexPath, atomically: true, encoding: .utf8)
            
            // 6. 打包为 .mrpack
            // 再次获取最新进度数据，确保进度条数据保留
            currentProgress = await progressUpdater.getFullProgress()
            currentProgress.progress = 0.95
            // 在打包过程中保持进度条显示（确保进度条数据保留）
            progressCallback?(currentProgress)
            
            try ModPackArchiver.archive(tempDir: tempDir, outputPath: outputPath)
            
            // 打包完成，确保进度条显示100%
            // 再次获取最新进度数据
            currentProgress = await progressUpdater.getFullProgress()
            currentProgress.progress = 1.0
            // 确保扫描和复制进度条都显示100%，但保留最后一个处理的文件名
            if var scanProgress = currentProgress.scanProgress {
                scanProgress.progress = 1.0
                scanProgress.completed = scanProgress.total
                // 保留最后一个处理的文件名，不清空
                currentProgress.scanProgress = scanProgress
            }
            if var copyProgress = currentProgress.copyProgress {
                copyProgress.progress = 1.0
                copyProgress.completed = copyProgress.total
                // 保留最后一个处理的文件名，不清空
                currentProgress.copyProgress = copyProgress
            }
            progressCallback?(currentProgress)
            
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
}

