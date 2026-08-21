//
//  LitematicaService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftNBT

/// Reads and parses Litematica schematic files from game directories.
class LitematicaService {
    init() { }

    func loadLitematicaFiles(for gameName: String) async throws -> [LitematicaInfo] {
        let schematicsDir = AppPaths.schematicsDirectory(gameName: gameName)
        do {
            return try await Task.detached(priority: .userInitiated) {
                try loadLitematicaFilesSync(schematicsDir: schematicsDir)
            }.value
        } catch {
            AppLog.game.error("Failed to read Litematica file list: \(error.localizedDescription)")
            throw GlobalError.fileSystem(
                i18nKey: "error.filesystem.litematica_list_read_failed",
                level: .notification,
                message: "failed to read Litematica files from: \(schematicsDir.path), error: \(error.localizedDescription)",
            )
        }
    }

    func loadFullMetadata(filePath: URL) async throws -> LitematicMetadata? {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try loadFullMetadataSync(filePath: filePath)
            }.value
        } catch {
            AppLog.game.error("Failed to parse Litematica file: \(filePath.lastPathComponent), error: \(error)")
            throw error
        }
    }
}

private struct ListMetadata {
    let author: String?
    let description: String?
    let version: String?
    let regionCount: Int?
    let totalBlocks: Int?
}

private func parseListMetadata(filePath: URL) -> ListMetadata? {
    guard let data = try? Data(contentsOf: filePath),
          let nbtData = try? NBTDecoder().decode(data).root,
          let meta = nbtData["Metadata"]?.compoundValue else { return nil }
    let author = meta["Author"]?.stringValue
    let description = meta["Description"]?.stringValue
    let version = meta["Version"]?.stringValue
    let regionCount = meta["RegionCount"]?.int64Value.map(Int.init)
    let totalBlocks = meta["TotalBlocks"]?.int64Value.map(Int.init)
    return ListMetadata(author: author, description: description, version: version, regionCount: regionCount, totalBlocks: totalBlocks)
}

private func loadLitematicaFilesSync(schematicsDir: URL) throws -> [LitematicaInfo] {
    guard FileManager.default.fileExists(atPath: schematicsDir.path) else { return [] }
    let contents = try FileManager.default.contentsOfDirectory(
        at: schematicsDir,
        includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .fileSizeKey],
        options: [.skipsHiddenFiles],
    )
    var litematicaFiles: [LitematicaInfo] = []
    for filePath in contents {
        guard let isFile = try? filePath.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile == true else { continue }
        guard filePath.pathExtension.lowercased() == "litematic" else { continue }
        let fileName = filePath.lastPathComponent
        let creationDate = try? filePath.resourceValues(forKeys: [.creationDateKey]).creationDate
        let fileSize = (try? filePath.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let metadata = parseListMetadata(filePath: filePath)
        litematicaFiles.append(LitematicaInfo(
            name: fileName,
            path: filePath,
            createdDate: creationDate,
            fileSize: Int64(fileSize),
            author: metadata?.author,
            description: metadata?.description,
            version: metadata?.version,
            regionCount: metadata?.regionCount,
            totalBlocks: metadata?.totalBlocks,
        ))
    }
    litematicaFiles.sort { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
    return litematicaFiles
}

private func loadFullMetadataSync(filePath: URL) throws -> LitematicMetadata? {
    let data = try Data(contentsOf: filePath)
    let nbtData = try NBTDecoder().decode(data).root
    guard let metadata = nbtData["Metadata"]?.compoundValue else { return nil }
    let name = metadata["Name"]?.stringValue ?? filePath.deletingPathExtension().lastPathComponent
    let author = metadata["Author"]?.stringValue ?? ""
    let description = metadata["Description"]?.stringValue ?? ""
    var timeCreated: Int64 = 0, timeModified: Int64 = 0
    if let tc = metadata["TimeCreated"]?.int64Value {
        timeCreated = tc
    }
    if let tm = metadata["TimeModified"]?.int64Value {
        timeModified = tm
    }
    var enclosingSize = Size(x: 0, y: 0, z: 0)
    if let sizeData = metadata["EnclosingSize"]?.compoundValue {
        enclosingSize = Size(
            x: sizeData["x"]?.intValue ?? 0,
            y: sizeData["y"]?.intValue ?? 0,
            z: sizeData["z"]?.intValue ?? 0,
        )
    }
    var totalVolume: Int32 = 0, totalBlocks: Int32 = 0, regionCount: Int32 = 0
    if let v = metadata["TotalVolume"]?.int64Value {
        totalVolume = Int32(v)
    }
    if let tb = metadata["TotalBlocks"]?.int64Value {
        totalBlocks = Int32(tb)
    }
    if let rc = metadata["RegionCount"]?.int64Value {
        regionCount = Int32(rc)
    }
    return LitematicMetadata(
        name: name,
        author: author,
        description: description,
        timeCreated: timeCreated,
        timeModified: timeModified,
        totalVolume: totalVolume,
        totalBlocks: totalBlocks,
        enclosingSize: enclosingSize,
        regionCount: regionCount,
    )
}
