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
struct ModPackArchiver {
    
    /// 打包整合包
    /// - Parameters:
    ///   - tempDir: 临时目录（包含 modrinth.index.json 和 overrides）
    ///   - outputPath: 输出文件路径
    static func archive(
        tempDir: URL,
        outputPath: URL
    ) throws {
        // 如果输出文件已存在，先删除
        if FileManager.default.fileExists(atPath: outputPath.path) {
            try FileManager.default.removeItem(at: outputPath)
        }
        
        // 创建 ZIP 归档
        guard let archive = Archive(url: outputPath, accessMode: .create) else {
            throw GlobalError.fileSystem(
                chineseMessage: "无法创建压缩文件: \(outputPath.path)",
                i18nKey: "error.modpack.export.archive_creation_failed",
                level: .notification
            )
        }
        
        // 添加 modrinth.index.json 到 zip 根目录
        let indexPath = tempDir.appendingPathComponent(AppConstants.modrinthIndexFileName)
        if FileManager.default.fileExists(atPath: indexPath.path) {
            let indexData = try Data(contentsOf: indexPath)
            try archive.addEntry(
                with: AppConstants.modrinthIndexFileName,
                type: .file,
                uncompressedSize: UInt32(indexData.count),
                compressionMethod: .deflate,
                provider: { (position, size) -> Data in
                    let start = Int(position)
                    let end = min(start + Int(size), indexData.count)
                    return indexData.subdata(in: start..<end)
                }
            )
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
                    // 使用标准化的路径来避免路径中包含 "private" 等词导致的问题
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
                    let fileSize = UInt32(fileData.count)
                    
                    try archive.addEntry(
                        with: relativePath,
                        type: .file,
                        uncompressedSize: fileSize,
                        compressionMethod: .deflate,
                        provider: { (position, size) -> Data in
                            let start = Int(position)
                            let end = min(start + Int(size), fileData.count)
                            return fileData.subdata(in: start..<end)
                        }
                    )
                }
            }
        }
    }
}


