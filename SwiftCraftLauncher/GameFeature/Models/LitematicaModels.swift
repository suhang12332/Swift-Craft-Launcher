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

    /// Creates a Litematica info with the specified parameters.
    /// - Parameters:
    ///   - name: The display name of the schematic.
    ///   - path: The file URL of the schematic.
    ///   - createdDate: The creation date, if available.
    init(
        name: String,
        path: URL,
        createdDate: Date? = nil,
    ) {
        id = path.lastPathComponent
        self.name = name
        self.path = path
        self.createdDate = createdDate
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
