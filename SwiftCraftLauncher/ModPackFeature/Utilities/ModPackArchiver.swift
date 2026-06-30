//
//  ModPackArchiver.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Archives a modpack directory into a `.mrpack` file.
enum ModPackArchiver {
    /// Creates a `.mrpack` archive from a temporary directory.
    /// - Parameters:
    ///   - tempDir: The temporary directory containing `modrinth.index.json` and `overrides`.
    ///   - outputPath: The destination file path for the archive.
    ///   - rootFiles: The root-level files to include. Defaults to the Modrinth index file.
    static func archive(
        tempDir: URL,
        outputPath: URL,
        rootFiles: [String] = [AppConstants.modrinthIndexFileName]
    ) throws {
        if Task.isCancelled { throw CancellationError() }

        if FileManager.default.fileExists(atPath: outputPath.path) {
            try FileManager.default.removeItem(at: outputPath)
        }

        let archive: Archive
        do {
            archive = try Archive(url: outputPath, accessMode: .create)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "无法创建压缩文件: \(outputPath.path)",
                i18nKey: "error.modpack.export.archive_creation_failed",
                level: .notification
            )
        }

        for fileName in rootFiles {
            if Task.isCancelled { throw CancellationError() }
            let filePath = tempDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: filePath.path) {
                let fileData = try Data(contentsOf: filePath)
                try archive.addEntry(
                    with: fileName,
                    type: .file,
                    uncompressedSize: Int64(fileData.count),
                    compressionMethod: .deflate
                ) { position, size -> Data in
                    let start = Int(position)
                    let end = min(start + size, fileData.count)
                    return fileData.subdata(in: start..<end)
                }
            }
        }

        let overridesDir = tempDir.appendingPathComponent("overrides")
        if FileManager.default.fileExists(atPath: overridesDir.path) {
            let overridesEnumerator = FileManager.default.enumerator(
                at: overridesDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            let overridesDirPath = (overridesDir.path as NSString).standardizingPath
            let overridesDirPathWithSlash = overridesDirPath.hasSuffix("/")
                ? overridesDirPath
                : overridesDirPath + "/"

            while let fileURL = overridesEnumerator?.nextObject() as? URL {
                if Task.isCancelled { throw CancellationError() }
                if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                   isRegularFile {
                    let filePath = (fileURL.path as NSString).standardizingPath

                    guard filePath.hasPrefix(overridesDirPathWithSlash) else {
                        Logger.shared.warning("文件路径不在 overrides 目录内: \(filePath)")
                        continue
                    }

                    let relativeToOverrides = String(filePath.dropFirst(overridesDirPathWithSlash.count))
                    let relativePath = "overrides/\(relativeToOverrides)"

                    let fileData = try Data(contentsOf: fileURL)
                    let fileSize = Int64(fileData.count)

                    try archive.addEntry(
                        with: relativePath,
                        type: .file,
                        uncompressedSize: fileSize,
                        compressionMethod: .deflate
                    ) { position, size -> Data in
                        let start = Int(position)
                        let end = min(start + size, fileData.count)
                        return fileData.subdata(in: start..<end)
                    }
                }
            }
        }
    }
}
