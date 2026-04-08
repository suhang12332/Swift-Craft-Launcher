//
//  ModPackArchiver.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation
import ZIPFoundation

/// 整合包打包器
/// 负责将临时目录打包为 .mrpack 文件
enum ModPackArchiver {
    /// 打包整合包
    /// - Parameters:
    ///   - tempDir: 临时目录（包含 modrinth.index.json 和 overrides）
    ///   - outputPath: 输出文件路径
    static func archive(
        tempDir: URL,
        outputPath: URL,
        rootFiles: [String] = [AppConstants.modrinthIndexFileName]
    ) throws {
        // 如果输出文件已存在，先删除
        if FileManager.default.fileExists(atPath: outputPath.path) {
            try FileManager.default.removeItem(at: outputPath)
        }

        // 创建 ZIP 归档
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

        // 添加根目录文件（如 modrinth.index.json / manifest.json）
        for fileName in rootFiles {
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

        // 添加 overrides 文件夹及其所有内容到 zip 根目录
        let overridesDir = tempDir.appendingPathComponent("overrides")
        if FileManager.default.fileExists(atPath: overridesDir.path) {
            let overridesEnumerator = FileManager.default.enumerator(
                at: overridesDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            // 标准化 overridesDir 路径（确保以 / 结尾）
            let overridesDirPath = (overridesDir.path as NSString).standardizingPath
            let overridesDirPathWithSlash = overridesDirPath.hasSuffix("/")
                ? overridesDirPath
                : overridesDirPath + "/"

            while let fileURL = overridesEnumerator?.nextObject() as? URL {
                if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                   isRegularFile {
                    // 计算相对路径（相对于 overridesDir），添加 overrides/ 前缀
                    let filePath = (fileURL.path as NSString).standardizingPath

                    // 确保文件路径以 overridesDir 路径开头
                    guard filePath.hasPrefix(overridesDirPathWithSlash) else {
                        Logger.shared.warning("文件路径不在 overrides 目录内: \(filePath)")
                        continue
                    }

                    // 提取相对路径部分
                    let relativeToOverrides = String(filePath.dropFirst(overridesDirPathWithSlash.count))
                    // 构建 ZIP 中的路径（以 overrides/ 开头）
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
