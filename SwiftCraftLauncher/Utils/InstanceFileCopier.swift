//
//  InstanceFileCopier.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 实例文件合并工具
/// 负责将源游戏目录的文件合并到目标游戏目录
enum InstanceFileCopier {

    /// 通用的合并文件夹方法
    /// - Parameters:
    ///   - sourceDirectory: 源目录
    ///   - targetDirectory: 目标目录
    ///   - fileFilter: 可选的文件过滤函数，返回 true 表示保留文件，false 表示过滤掉
    ///   - onProgress: 进度回调 (fileName, completed, total)
    /// - Throws: 合并过程中的错误
    static func copyDirectory(
        from sourceDirectory: URL,
        to targetDirectory: URL,
        fileFilter: ((String) -> Bool)? = nil,
        onProgress: ((String, Int, Int) -> Void)?
    ) async throws {
        let fileManager = FileManager.default

        // 确保目标目录存在
        try fileManager.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )

        // 获取所有需要合并的文件
        let allFiles = try getAllFiles(in: sourceDirectory)

        // 标准化源目录路径（解析符号链接，确保路径一致性）
        let standardizedSourceURL = sourceDirectory.resolvingSymlinksInPath()
        let sourcePath = getNormalizedPath(standardizedSourceURL.path)

        // 标准化所有文件路径并应用文件过滤（如果有）
        let filesToCopy: [(sourceURL: URL, relativePath: String, targetURL: URL)]
        if let fileFilter = fileFilter {
            filesToCopy = allFiles.compactMap { fileURL in
                let standardizedFileURL = fileURL.resolvingSymlinksInPath()
                let filePath = standardizedFileURL.path

                guard filePath.hasPrefix(sourcePath) else {
                    Logger.shared.warning("文件路径不在源目录内: \(filePath) (源目录: \(sourcePath))")
                    return nil
                }

                let relativePath = String(filePath.dropFirst(sourcePath.count))
                guard fileFilter(relativePath) else {
                    return nil
                }

                let targetURL = targetDirectory.appendingPathComponent(relativePath)
                return (sourceURL: fileURL, relativePath: relativePath, targetURL: targetURL)
            }
        } else {
            filesToCopy = allFiles.compactMap { fileURL in
                let standardizedFileURL = fileURL.resolvingSymlinksInPath()
                let filePath = standardizedFileURL.path

                guard filePath.hasPrefix(sourcePath) else {
                    Logger.shared.warning("文件路径不在源目录内: \(filePath) (源目录: \(sourcePath))")
                    return nil
                }

                let relativePath = String(filePath.dropFirst(sourcePath.count))
                let targetURL = targetDirectory.appendingPathComponent(relativePath)
                return (sourceURL: fileURL, relativePath: relativePath, targetURL: targetURL)
            }
        }

        let totalFiles = filesToCopy.count
        let filteredCount = allFiles.count - totalFiles

        if filteredCount > 0 {
            Logger.shared.info("开始合并目录: \(sourceDirectory.path) -> \(targetDirectory.path), 共 \(totalFiles) 个文件（已过滤 \(filteredCount) 个文件）")
        } else {
            Logger.shared.info("开始合并目录: \(sourceDirectory.path) -> \(targetDirectory.path), 共 \(totalFiles) 个文件")
        }

        var completed = 0
        for (sourceURL, _, targetURL) in filesToCopy {
            // 检查任务是否被取消
            try Task.checkCancellation()

            // 创建目标目录（如果需要）
            let targetDir = targetURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: targetDir,
                withIntermediateDirectories: true
            )

            // 合并文件（如果目标文件已存在，先删除再合并）
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)

            completed += 1
            onProgress?(sourceURL.lastPathComponent, completed, totalFiles)

            // 避免 CPU 占用过高
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        Logger.shared.info("目录合并完成: \(completed)/\(totalFiles) 个文件")
    }

    /// 合并游戏目录内容到目标目录（启动器导入专用）
    /// - Parameters:
    ///   - sourceDirectory: 源游戏目录（.minecraft 文件夹）
    ///   - targetDirectory: 目标游戏目录（Profile 目录）
    ///   - launcherType: 启动器类型（用于文件过滤）
    ///   - onProgress: 进度回调 (fileName, completed, total)
    /// - Throws: 合并过程中的错误
    static func copyGameDirectory(
        from sourceDirectory: URL,
        to targetDirectory: URL,
        launcherType: ImportLauncherType,
        onProgress: ((String, Int, Int) -> Void)?
    ) async throws {
        // 使用通用合并方法，并应用启动器特定的文件过滤
        try await copyDirectory(
            from: sourceDirectory,
            to: targetDirectory,
            fileFilter: { relativePath in
                !LauncherFileFilter.shouldFilter(fileName: relativePath, launcherType: launcherType)
            },
            onProgress: onProgress
        )
    }

    /// 递归获取目录中的所有文件
    internal static func getAllFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        var files: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                files.append(fileURL)
            }
        }

        return files
    }

    /// 获取标准化的路径（确保以 / 结尾）
    private static func getNormalizedPath(_ path: String) -> String {
        return path.hasSuffix("/") ? path : path + "/"
    }
}
