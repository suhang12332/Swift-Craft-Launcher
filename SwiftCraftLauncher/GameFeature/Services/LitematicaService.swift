//
//  LitematicaService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftNBT

/// Reads and parses Litematica schematic files from game directories.
final class LitematicaService {
    func loadLitematicaFiles(for gameName: String) async throws -> [LitematicaInfo] {
        let schematicsDir = AppPaths.schematicsDirectory(gameName: gameName)
        return try await Task.detached(priority: .userInitiated) {
            try loadLitematicaFilesSync(schematicsDir: schematicsDir)
        }.value
    }

    func loadFullMetadata(filePath: URL) async throws -> LitematicMetadata? {
        try await Task.detached(priority: .userInitiated) {
            try loadFullMetadataSync(filePath: filePath)
        }.value
    }
}

private func loadLitematicaFilesSync(schematicsDir: URL) throws -> [LitematicaInfo] {
    guard FileManager.default.fileExists(atPath: schematicsDir.path) else { return [] }
    let contents = try FileManager.default.contentsOfDirectory(
        at: schematicsDir,
        includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
        options: [.skipsHiddenFiles],
    )
    var litematicaFiles: [LitematicaInfo] = []
    for filePath in contents {
        guard filePath.pathExtension.lowercased() == "litematic" else { continue }
        let values = try? filePath.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey])
        guard values?.isRegularFile == true else { continue }
        litematicaFiles.append(LitematicaInfo(
            name: filePath.lastPathComponent,
            path: filePath,
            createdDate: values?.creationDate,
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
        totalVolume = Int32(clamping: v)
    }
    if let tb = metadata["TotalBlocks"]?.int64Value {
        totalBlocks = Int32(clamping: tb)
    }
    if let rc = metadata["RegionCount"]?.int64Value {
        regionCount = Int32(clamping: rc)
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
