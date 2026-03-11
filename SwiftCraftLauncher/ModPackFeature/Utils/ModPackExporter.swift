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
    ///   - selectedFiles: 在文件树中勾选的文件（只导出这些）
    ///   - progressCallback: 进度回调
    /// - Returns: 导出结果
    static func exportModPack(
        gameInfo: GameVersionInfo,
        outputPath: URL,
        modPackName: String,
        modPackVersion: String = "1.0.0",
        summary: String? = nil,
        selectedFiles: [URL],
        progressCallback: ((ExportProgress) -> Void)? = nil
    ) async -> ExportResult {
        do {
            // 1. 初始化进度
            progressCallback?(ExportProgress())

            // 2. 准备临时目录
            let (tempDir, overridesDir) = try prepareDirectories()
            defer {
                // 清理临时目录
                try? FileManager.default.removeItem(at: tempDir)
            }

            // 3. 仅基于用户勾选的文件计算总数
            let resolvedFiles = resolveSelectedFiles(from: selectedFiles)
            let gameDirectory = AppPaths.profileDirectory(gameName: gameInfo.gameName)
            // 参与扫描的资源数：仅限游戏根目录下的 mods / shaderpacks / resourcepacks / datapacks
            let totalScanResources = resolvedFiles.filter { shouldScanForModrinth($0, gameDirectory: gameDirectory) }.count
            // 4. 使用真实的资源总数初始化扫描进度条
            var initialProgress = ExportProgress()
            if totalScanResources > 0 {
                initialProgress.scanProgress = ExportProgress.ProgressItem(
                    title: "modpack.export.scanning.title".localized(),
                    progress: 0.0,
                    currentFile: "",
                    completed: 0,
                    total: totalScanResources
                )
            }
            progressCallback?(initialProgress)

            // 5. 扫描识别所有资源文件
            let progressUpdater = ProgressUpdater()

            let (indexFiles, filesToCopy) = await identifySelectedResources(
                gameInfo: gameInfo,
                selectedFiles: resolvedFiles,
                totalResources: totalScanResources,
                progressUpdater: progressUpdater,
                progressCallback: progressCallback
            )

            // 6. 复制需要复制的资源文件
            let copyCounter = CopyCounter(total: filesToCopy.count)

            try await copyFiles(
                params: CopyFilesParams(
                    filesToCopy: filesToCopy,
                    overridesDir: overridesDir
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
        let filesToCopy: [(file: URL, relativePath: String)]
        let overridesDir: URL
    }

    /// 准备临时目录和 overrides 目录结构
    private static func prepareDirectories() throws -> (tempDir: URL, overridesDir: URL) {
        let tempDir = try createTempDirectory()
        let overridesDir = tempDir.appendingPathComponent("overrides")
        try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)

        // 创建各种资源的 overrides 子目录
        for resourceType in ResourceType.allCases {
            let subDir = overridesDir.appendingPathComponent(resourceType.overridesSubdirectory)
            try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        }

        return (tempDir, overridesDir)
    }

    /// 基于勾选的文件识别资源
    /// 仅对 mods / shaderpacks / resourcepacks / datapacks 进行 Modrinth 扫描，
    /// 其他文件直接标记为需要复制到 overrides，且保留相对于游戏目录的原始路径结构。
    private static func identifySelectedResources(
        gameInfo: GameVersionInfo,
        selectedFiles: [URL],
        totalResources: Int,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?
    ) async -> ([ModrinthIndexFile], [(file: URL, relativePath: String)]) {
        // 不需要扫描的文件加入待复制列表
        var indexFiles: [ModrinthIndexFile] = []
        var filesToCopy: [(file: URL, relativePath: String)] = []

        let gameDirectory = AppPaths.profileDirectory(gameName: gameInfo.gameName)
        let processedCounter = ProcessedCounter()

        for file in selectedFiles where !shouldScanForModrinth(file, gameDirectory: gameDirectory) {
            let relativePath = makeRelativePath(for: file, gameDirectory: gameDirectory)
            filesToCopy.append((file: file, relativePath: relativePath))
        }

        // 对需要扫描的资源（mods / shaderpacks / resourcepacks / datapacks）并发识别
        return await withTaskGroup(of: ResourceProcessor.ProcessResult.self) { group in
            for file in selectedFiles where shouldScanForModrinth(file, gameDirectory: gameDirectory) {
                group.addTask {
                    // 对参与扫描的资源：子目录按资源类型(四大目录)归类
                    let relativePath = inferOverridesSubdirectory(for: file, gameDirectory: gameDirectory)
                    let result = await ResourceProcessor.identify(
                        file: file,
                        relativePath: relativePath
                    )

                    // 更新扫描进度
                    let processed = await processedCounter.increment()
                    let scanTotal = max(totalResources, 1) // 至少为1，避免除零错误
                    let updatedProgress = await progressUpdater.advanceScanProgress(
                        processed: processed,
                        total: scanTotal,
                        currentFile: result.sourceFile.lastPathComponent
                    )
                    progressCallback?(updatedProgress)

                    return result
                }
            }

            // 收集扫描结果
            for await result in group {
                if let indexFile = result.indexFile {
                    // 成功识别到 Modrinth 资源，添加到索引
                    indexFiles.append(indexFile)
                } else if result.shouldCopyToOverrides {
                    // 未识别到或识别失败，需要复制到 overrides
                    filesToCopy.append((file: result.sourceFile, relativePath: result.relativePath))
                }
            }

            return (indexFiles, filesToCopy)
        }
    }

    /// 根据文件路径推断 overrides 子目录（用于四大资源目录）
    /// 仅当文件位于游戏根目录下的四大目录时，才归类到对应的 overrides 子目录
    private static func inferOverridesSubdirectory(for file: URL, gameDirectory: URL) -> String {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory) else {
            return makeRelativePath(for: file, gameDirectory: gameDirectory)
        }

        let lowercasedTopLevel = topLevel.lowercased()

        if lowercasedTopLevel == AppConstants.DirectoryNames.datapacks.lowercased() {
            return AppConstants.DirectoryNames.datapacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.shaderpacks.lowercased() {
            return AppConstants.DirectoryNames.shaderpacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.resourcepacks.lowercased() {
            return AppConstants.DirectoryNames.resourcepacks
        }
        if lowercasedTopLevel == AppConstants.DirectoryNames.mods.lowercased() {
            return AppConstants.DirectoryNames.mods
        }

        // 其他顶级目录：保留相对路径结构
        return makeRelativePath(for: file, gameDirectory: gameDirectory)
    }

    /// 提取相对于游戏目录的顶级目录名（例如 "游戏名/mods/foo.jar" -> "mods"）
    private static func topLevelDirectoryName(of file: URL, gameDirectory: URL) -> String? {
        let filePath = file.standardizedFileURL.path
        let rootPath = gameDirectory.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            return nil
        }

        let relative = String(filePath.dropFirst(rootPath.count))
        let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            return nil
        }

        if let firstSlash = trimmed.firstIndex(of: "/") {
            return String(trimmed[..<firstSlash])
        } else {
            // 没有 "/"，说明文件直接位于游戏根目录下
            return trimmed
        }
    }

    /// 是否需要进行 Modrinth 扫描的资源
    /// 仅当文件位于游戏根目录下的 mods / shaderpacks / resourcepacks / datapacks 顶级目录时才参与扫描
    private static func shouldScanForModrinth(_ file: URL, gameDirectory: URL) -> Bool {
        guard let topLevel = topLevelDirectoryName(of: file, gameDirectory: gameDirectory)?.lowercased() else {
            return false
        }

        return topLevel == AppConstants.DirectoryNames.datapacks.lowercased()
        || topLevel == AppConstants.DirectoryNames.shaderpacks.lowercased()
        || topLevel == AppConstants.DirectoryNames.resourcepacks.lowercased()
        || topLevel == AppConstants.DirectoryNames.mods.lowercased()
    }

    /// 计算文件相对于游戏目录的相对路径，用于在 overrides 中保持原始目录结构
    private static func makeRelativePath(for file: URL, gameDirectory: URL) -> String {
        let filePath = file.standardizedFileURL.path
        let rootPath = gameDirectory.standardizedFileURL.path

        if filePath.hasPrefix(rootPath) {
            let relative = String(filePath.dropFirst(rootPath.count))
            // 去掉前导 "/"，得到形如 "config/foo/bar.json"
            let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            // 只保留目录部分，去掉文件名；如果没有 "/"，说明在游戏根目录下，返回空目录
            if let lastSlash = trimmed.lastIndex(of: "/") {
                return String(trimmed[..<lastSlash])
            } else {
                return ""
            }
        } else {
            return ""
        }
    }

    /// 将可能包含目录的选择列表解析为最终要处理的文件列表
    /// - Parameter urls: 用户在文件树中勾选的路径（可能是文件也可能是文件夹）
    /// - Returns: 展开后的所有文件路径
    private static func resolveSelectedFiles(from urls: [URL]) -> [URL] {
        guard !urls.isEmpty else { return [] }

        let fm = FileManager.default
        var result: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // 目录：递归收集其中的所有普通文件
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                           isRegularFile == true {
                            result.append(fileURL)
                        }
                    }
                }
            } else {
                // 普通文件：直接加入结果
                result.append(url)
            }
        }

        return result
    }

    /// 复制资源文件
    private static func copyFiles(
        params: CopyFilesParams,
        copyCounter: CopyCounter,
        progressUpdater: ProgressUpdater,
        progressCallback: ((ExportProgress) -> Void)?
    ) async throws {
        let filesToCopy = params.filesToCopy
        let overridesDir = params.overridesDir
        let totalFilesToCopy = filesToCopy.count

        // 更新复制进度条的总数
        if totalFilesToCopy > 0 {
            await progressUpdater.setCopyProgressTotal(totalFilesToCopy)
            let updatedProgress = await progressUpdater.getFullProgress()
            progressCallback?(updatedProgress)
        }

        // 复制资源文件
        await withTaskGroup(of: Void.self) { group in
            for (file, relativePath) in filesToCopy {
                group.addTask {
                    do {
                        try ResourceProcessor.copyToOverrides(
                            file: file,
                            relativePath: relativePath,
                            overridesDir: overridesDir
                        )

                        // 更新复制进度
                        let (processed, total) = await copyCounter.increment()
                        let updatedProgress = await progressUpdater.advanceCopyProgress(
                            processed: processed,
                            total: total,
                            currentFile: file.lastPathComponent
                        )
                        progressCallback?(updatedProgress)
                    } catch {
                        Logger.shared.warning("复制资源文件失败: \(file.lastPathComponent), 错误: \(error.localizedDescription)")

                        // 更新进度（即使失败也计入已处理）
                        let (processed, total) = await copyCounter.increment()
                        let updatedProgress = await progressUpdater.advanceCopyProgress(
                            processed: processed,
                            total: total,
                            currentFile: file.lastPathComponent
                        )
                        progressCallback?(updatedProgress)
                    }
                }
            }

            // 等待所有复制任务完成
            for await _ in group {}
        }
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
        let indexJson = try await ModrinthIndexBuilder.build(
            gameInfo: params.gameInfo,
            modPackName: params.modPackName,
            modPackVersion: params.modPackVersion,
            summary: params.summary,
            files: params.indexFiles
        )

        let indexPath = tempDir.appendingPathComponent(AppConstants.modrinthIndexFileName)
        try indexJson.write(to: indexPath, atomically: true, encoding: String.Encoding.utf8)

        // 仅记录生成 modrinth.index.json 的进度（视为该阶段完成）
        let currentProgress = await progressUpdater.getFullProgress()
        progressCallback?(currentProgress)

        // 打包为 .mrpack
        try ModPackArchiver.archive(tempDir: tempDir, outputPath: outputPath)
    }

    // MARK: - Progress Management Types

    /// 进度更新器
    private actor ProgressUpdater {
        private var scanProgress: ExportProgress.ProgressItem?
        private var copyProgress: ExportProgress.ProgressItem?

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

        /// 扫描阶段：根据已处理数量更新进度，并返回完整进度
        func advanceScanProgress(
            processed: Int,
            total: Int,
            currentFile: String
        ) -> ExportProgress {
            let safeTotal = max(total, 1)
            let scanItem = ExportProgress.ProgressItem(
                title: "modpack.export.scanning.title".localized(),
                progress: Double(processed) / Double(safeTotal),
                currentFile: currentFile,
                completed: processed,
                total: safeTotal
            )
            scanProgress = scanItem
            return getFullProgress()
        }

        /// 复制阶段：根据已处理数量更新进度，并返回完整进度
        func advanceCopyProgress(
            processed: Int,
            total: Int,
            currentFile: String
        ) -> ExportProgress {
            let safeTotal = max(total, 1)
            let copyItem = ExportProgress.ProgressItem(
                title: "modpack.export.copying.title".localized(),
                progress: Double(processed) / Double(safeTotal),
                currentFile: currentFile,
                completed: processed,
                total: safeTotal
            )
            copyProgress = copyItem
            return getFullProgress()
        }

        func getFullProgress() -> ExportProgress {
            return ExportProgress(
                scanProgress: scanProgress,
                copyProgress: copyProgress
            )
        }
    }

    /// 已处理文件计数器
    private actor ProcessedCounter {
        private var count = 0

        func increment() -> Int {
            count += 1
            return count
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
