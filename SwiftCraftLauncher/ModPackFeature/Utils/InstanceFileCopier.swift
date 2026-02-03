//
//  InstanceFileCopier.swift
//  SwiftCraftLauncher
//

import Foundation

enum InstanceFileCopier {

    static func copyDirectory(
        from sourceDirectory: URL,
        to targetDirectory: URL,
        fileFilter: ((String) -> Bool)? = nil,
        onProgress: ((String, Int, Int) -> Void)?
    ) async throws {
        let fileManager = FileManager.default

        try fileManager.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )

        let allFiles = try getAllFiles(in: sourceDirectory)

        let standardizedSourceURL = sourceDirectory.resolvingSymlinksInPath()
        let sourcePath = getNormalizedPath(standardizedSourceURL.path)

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
            try Task.checkCancellation()

            let targetDir = targetURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: targetDir,
                withIntermediateDirectories: true
            )

            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)

            completed += 1
            onProgress?(sourceURL.lastPathComponent, completed, totalFiles)

            try await Task.sleep(nanoseconds: 1_000_000)
        }

        Logger.shared.info("目录合并完成: \(completed)/\(totalFiles) 个文件")
    }

    static func copyGameDirectory(
        from sourceDirectory: URL,
        to targetDirectory: URL,
        launcherType: ImportLauncherType,
        onProgress: ((String, Int, Int) -> Void)?
    ) async throws {
        try await copyDirectory(
            from: sourceDirectory,
            to: targetDirectory,
            fileFilter: { relativePath in
                !LauncherFileFilter.shouldFilter(fileName: relativePath, launcherType: launcherType)
            },
            onProgress: onProgress
        )
    }

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

    private static func getNormalizedPath(_ path: String) -> String {
        return path.hasSuffix("/") ? path : path + "/"
    }
}
