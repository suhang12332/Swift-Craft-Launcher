//
//  InstanceFileCopier.swift
//  SwiftCraftLauncher
//
//

import Foundation

/// 实例文件复制工具
/// 负责将源游戏目录的文件复制到目标游戏目录
enum InstanceFileCopier {

    /// 复制游戏目录内容到目标目录
    /// - Parameters:
    ///   - sourceDirectory: 源游戏目录（.minecraft 文件夹）
    ///   - targetDirectory: 目标游戏目录（Profile 目录）
    ///   - launcherType: 启动器类型（用于文件过滤）
    ///   - onProgress: 进度回调 (fileName, completed, total)
    /// - Throws: 复制过程中的错误
    static func copyGameDirectory(
        from sourceDirectory: URL,
        to targetDirectory: URL,
        launcherType: ImportLauncherType,
        onProgress: ((String, Int, Int) -> Void)?
    ) async throws {
        let fileManager = FileManager.default

        // 确保目标目录存在
        try fileManager.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )

        // 获取所有需要复制的文件
        let allFiles = try getAllFiles(in: sourceDirectory)

        // 根据启动器类型过滤文件
        let filesToCopy = LauncherFileFilter.filterFiles(
            allFiles,
            sourceDirectory: sourceDirectory,
            launcherType: launcherType
        )

        let totalFiles = filesToCopy.count
        let filteredCount = allFiles.count - totalFiles

        Logger.shared.info("开始复制游戏目录: \(sourceDirectory.path) -> \(targetDirectory.path), 共 \(totalFiles) 个文件（已过滤 \(filteredCount) 个文件）")

        var completed = 0
        for fileURL in filesToCopy {
            // 计算相对路径
            let relativePath = fileURL.path.replacingOccurrences(
                of: sourceDirectory.path + "/",
                with: ""
            )

            let targetURL = targetDirectory.appendingPathComponent(relativePath)

            // 创建目标目录（如果需要）
            let targetDir = targetURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: targetDir,
                withIntermediateDirectories: true
            )

            // 复制文件
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: fileURL, to: targetURL)

            completed += 1
            onProgress?(fileURL.lastPathComponent, completed, totalFiles)

            // 避免 CPU 占用过高
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        Logger.shared.info("游戏目录复制完成: \(completed)/\(totalFiles) 个文件")
    }

    /// 递归获取目录中的所有文件
    private static func getAllFiles(in directory: URL) throws -> [URL] {
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
}
