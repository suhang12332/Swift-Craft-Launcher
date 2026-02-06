//
//  LitematicaService.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// Litematica 投影文件服务
/// 负责读取和解析 Litematica 投影文件
@MainActor
class LitematicaService {
    static let shared = LitematicaService()

    private init() {}

    /// 从游戏目录读取 Litematica 投影文件列表
    /// - Parameter gameName: 游戏名称
    /// - Returns: Litematica 投影文件列表
    func loadLitematicaFiles(for gameName: String) async throws -> [LitematicaInfo] {
        let schematicsDir = AppPaths.schematicsDirectory(gameName: gameName)
        do {
            return try await Task.detached(priority: .userInitiated) {
                try loadLitematicaFilesSync(schematicsDir: schematicsDir)
            }.value
        } catch {
            Logger.shared.error("读取 Litematica 文件列表失败: \(error.localizedDescription)")
            throw GlobalError.fileSystem(
                chineseMessage: "读取 Litematica 文件列表失败",
                i18nKey: "error.filesystem.litematica_list_read_failed",
                level: .notification
            )
        }
    }

    /// 解析 Litematica 文件的元数据（用于列表显示）
    /// - Parameter filePath: 文件路径
    /// - Returns: 元数据信息
    private func parseLitematicaMetadata(filePath: URL) async throws -> LitematicaMetadata? {
        try await Task.detached(priority: .userInitiated) {
            try parseLitematicaMetadataSync(filePath: filePath)
        }.value
    }

    /// 读取完整的 Litematica 投影元数据
    /// - Parameter filePath: 文件路径
    /// - Returns: 完整的元数据信息
    func loadFullMetadata(filePath: URL) async throws -> LitematicMetadata? {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try loadFullMetadataSync(filePath: filePath)
            }.value
        } catch {
            Logger.shared.error("解析Litematica文件失败: \(filePath.lastPathComponent), 错误: \(error)")
            throw error
        }
    }
}

// MARK: - 文件内同步辅助（在 Task.detached 中调用，避免主线程文件 I/O）
private func parseLitematicaMetadataSync(filePath: URL) throws -> LitematicaMetadata? {
    let data = try Data(contentsOf: filePath)
    let parser = NBTParser(data: data)
    let nbtData = try parser.parse()
    guard let metadata = nbtData["Metadata"] as? [String: Any] else { return nil }
    let author = metadata["Author"] as? String
    let description = metadata["Description"] as? String
    let version = metadata["Version"] as? String
    var regionCount: Int?
    var totalBlocks: Int?
    if let rc = metadata["RegionCount"] {
        if let rcInt = rc as? Int32 { regionCount = Int(rcInt) } else if let rcInt = rc as? Int { regionCount = rcInt }
    }
    if let tb = metadata["TotalBlocks"] {
        if let tbInt = tb as? Int32 { totalBlocks = Int(tbInt) } else if let tbInt = tb as? Int { totalBlocks = tbInt }
    }
    return LitematicaMetadata(
        author: author,
        description: description,
        version: version,
        regionCount: regionCount,
        totalBlocks: totalBlocks
    )
}

private func loadLitematicaFilesSync(schematicsDir: URL) throws -> [LitematicaInfo] {
    guard FileManager.default.fileExists(atPath: schematicsDir.path) else { return [] }
    let contents = try FileManager.default.contentsOfDirectory(
        at: schematicsDir,
        includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
    )
    var litematicaFiles: [LitematicaInfo] = []
    for filePath in contents {
        guard let isFile = try? filePath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile == true else { continue }
        guard filePath.pathExtension.lowercased() == "litematic" else { continue }
        let fileName = filePath.lastPathComponent
        let creationDate = try? filePath.resourceValues(forKeys: [.creationDateKey]).creationDate
        let fileSize = (try? filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let metadata = try? parseLitematicaMetadataSync(filePath: filePath)
        litematicaFiles.append(LitematicaInfo(
            name: fileName,
            path: filePath,
            createdDate: creationDate,
            fileSize: Int64(fileSize),
            author: metadata?.author,
            description: metadata?.description,
            version: metadata?.version,
            regionCount: metadata?.regionCount,
            totalBlocks: metadata?.totalBlocks
        ))
    }
    litematicaFiles.sort { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
    return litematicaFiles
}

private func loadFullMetadataSync(filePath: URL) throws -> LitematicMetadata? {
    let data = try Data(contentsOf: filePath)
    let parser = NBTParser(data: data)
    let nbtData = try parser.parse()
    guard let metadata = nbtData["Metadata"] as? [String: Any] else { return nil }
    let name = (metadata["Name"] as? String) ?? filePath.deletingPathExtension().lastPathComponent
    let author = (metadata["Author"] as? String) ?? ""
    let description = (metadata["Description"] as? String) ?? ""
    var timeCreated: Int64 = 0, timeModified: Int64 = 0
    if let tc = metadata["TimeCreated"] {
        if let tcLong = tc as? Int64 { timeCreated = tcLong } else if let tcInt = tc as? Int32 { timeCreated = Int64(tcInt) } else if let tcInt = tc as? Int { timeCreated = Int64(tcInt) }
    }
    if let tm = metadata["TimeModified"] {
        if let tmLong = tm as? Int64 { timeModified = tmLong } else if let tmInt = tm as? Int32 { timeModified = Int64(tmInt) } else if let tmInt = tm as? Int { timeModified = Int64(tmInt) }
    }
    var enclosingSize = Size(x: 0, y: 0, z: 0)
    if let sizeData = metadata["EnclosingSize"] as? [String: Any] {
        enclosingSize = Size(
            x: (sizeData["x"] as? Int32) ?? 0,
            y: (sizeData["y"] as? Int32) ?? 0,
            z: (sizeData["z"] as? Int32) ?? 0
        )
    }
    var totalVolume: Int32 = 0, totalBlocks: Int32 = 0, regionCount: Int32 = 0
    if let tv = metadata["TotalVolume"] { if let v = tv as? Int32 { totalVolume = v } else if let v = tv as? Int { totalVolume = Int32(v) } }
    if let tb = metadata["TotalBlocks"] { if let v = tb as? Int32 { totalBlocks = v } else if let v = tb as? Int { totalBlocks = Int32(v) } }
    if let rc = metadata["RegionCount"] { if let v = rc as? Int32 { regionCount = v } else if let v = rc as? Int { regionCount = Int32(v) } }
    return LitematicMetadata(
        name: name,
        author: author,
        description: description,
        timeCreated: timeCreated,
        timeModified: timeModified,
        totalVolume: totalVolume,
        totalBlocks: totalBlocks,
        enclosingSize: enclosingSize,
        regionCount: regionCount
    )
}
