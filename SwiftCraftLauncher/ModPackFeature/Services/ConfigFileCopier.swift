//
//  ConfigFileCopier.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation

/// 配置文件复制器
/// 负责复制游戏配置文件到 overrides 目录（排除存档目录和资源目录）
enum ConfigFileCopier {

    /// 需要排除的目录（这些目录已经在其他地方处理或不应该被复制）
    private static let excludedDirectories: Set<String> = [
        AppConstants.DirectoryNames.mods,
        AppConstants.DirectoryNames.datapacks,
        AppConstants.DirectoryNames.resourcepacks,
        AppConstants.DirectoryNames.shaderpacks,
        AppConstants.DirectoryNames.saves,
        AppConstants.DirectoryNames.crashReports,
        AppConstants.DirectoryNames.logs,
    ]

    /// 统计需要复制的配置文件数量
    /// - Parameter gameInfo: 游戏信息
    /// - Returns: 文件总数
    static func countFiles(gameInfo: GameVersionInfo) throws -> Int {
        let profileDir = AppPaths.profileDirectory(gameName: gameInfo.gameName)
        var count = 0

        // 获取所有目录和文件
        let contents = try FileManager.default.contentsOfDirectory(
            at: profileDir,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let isRegularFile = resourceValues?.isRegularFile ?? false

            if isDirectory {
                let dirName = item.lastPathComponent
                // 排除不需要的目录
                if excludedDirectories.contains(dirName) {
                    continue
                }
                // 递归统计目录中的文件
                let enumerator = FileManager.default.enumerator(
                    at: item,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                       isRegularFile {
                        count += 1
                    }
                }
            } else if isRegularFile {
                // 统计根目录下的配置文件
                count += 1
            }
        }

        return count
    }

    /// 复制配置文件到 overrides 目录
    /// - Parameters:
    ///   - gameInfo: 游戏信息
    ///   - overridesDir: overrides 目录
    ///   - progressCallback: 进度回调 (已复制文件数, 当前文件名)
    static func copyFiles(
        gameInfo: GameVersionInfo,
        to overridesDir: URL,
        progressCallback: ((Int, String) -> Void)? = nil
    ) async throws {
        let profileDir = AppPaths.profileDirectory(gameName: gameInfo.gameName)
        var filesCopied = 0

        // 获取所有目录和文件
        let contents = try FileManager.default.contentsOfDirectory(
            at: profileDir,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let isDirectory = resourceValues?.isDirectory ?? false
            let isRegularFile = resourceValues?.isRegularFile ?? false

            if isDirectory {
                let dirName = item.lastPathComponent
                // 排除不需要的目录
                if excludedDirectories.contains(dirName) {
                    continue
                }

                // 复制整个目录
                let destDir = overridesDir.appendingPathComponent(dirName)
                try? FileManager.default.removeItem(at: destDir)

                // 递归复制目录中的所有文件
                let enumerator = FileManager.default.enumerator(
                    at: item,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                       isRegularFile {
                        let relativePath = fileURL.path.replacingOccurrences(of: item.path + "/", with: "")
                        let destFile = destDir.appendingPathComponent(relativePath)
                        let destParent = destFile.deletingLastPathComponent()
                        try FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
                        try FileManager.default.copyItem(at: fileURL, to: destFile)
                        filesCopied += 1
                        progressCallback?(filesCopied, fileURL.lastPathComponent)
                    }
                }
            } else if isRegularFile {
                // 复制根目录下的配置文件
                let destFile = overridesDir.appendingPathComponent(item.lastPathComponent)
                try? FileManager.default.removeItem(at: destFile)
                try FileManager.default.copyItem(at: item, to: destFile)
                filesCopied += 1
                progressCallback?(filesCopied, item.lastPathComponent)
            }
        }
    }
}
