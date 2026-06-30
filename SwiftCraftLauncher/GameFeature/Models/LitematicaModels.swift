//
//  LitematicaModels.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Represents a Litematica schematic file.
struct LitematicaInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: URL
    let createdDate: Date?
    let fileSize: Int64
    let author: String?
    let description: String?
    let version: String?
    let regionCount: Int?
    let totalBlocks: Int?

    /// Creates a Litematica info with the specified parameters.
    /// - Parameters:
    ///   - name: The display name of the schematic.
    ///   - path: The file URL of the schematic.
    ///   - createdDate: The creation date, if available.
    ///   - fileSize: The file size in bytes.
    ///   - author: The author name, if available.
    ///   - description: A description of the schematic, if available.
    ///   - version: The schematic version string, if available.
    ///   - regionCount: The number of regions, if available.
    ///   - totalBlocks: The total block count, if available.
    init(
        name: String,
        path: URL,
        createdDate: Date? = nil,
        fileSize: Int64 = 0,
        author: String? = nil,
        description: String? = nil,
        version: String? = nil,
        regionCount: Int? = nil,
        totalBlocks: Int? = nil,
    ) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
        self.fileSize = fileSize
        self.author = author
        self.description = description
        self.version = version
        self.regionCount = regionCount
        self.totalBlocks = totalBlocks
    }
}

/// Complete metadata for a Litematica schematic, used for detail display.
struct LitematicMetadata {
    let name: String
    let author: String
    let description: String
    let timeCreated: Int64
    let timeModified: Int64
    let totalVolume: Int32
    let totalBlocks: Int32
    let enclosingSize: Size
    let regionCount: Int32
}

/// A three-dimensional size value.
struct Size {
    let x: Int32
    let y: Int32
    let z: Int32
}
