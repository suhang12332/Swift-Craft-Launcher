//
//  SkinLibraryItem.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// An item stored in the local skin library.
struct SkinLibraryItem: Codable, Equatable, Identifiable {
    /// The original file name of the skin image.
    let originalFileName: String

    /// The SHA-1 hash used as the unique storage key.
    let sha1: String

    /// The skin model type, either `steve` or `alex`.
    let model: PlayerSkinService.PublicSkinInfo.SkinModel

    /// The date this skin was last used.
    let lastUsedAt: Date

    /// The SHA-1 hash serves as the stable identifier.
    var id: String { sha1 }

    /// The file URL of the cached skin image on disk.
    var fileURL: URL {
        AppPaths.skinsDirectory.appendingPathComponent("\(sha1).png")
    }

    /// A human-readable display name derived from the original file name.
    var displayName: String {
        let trimmed = originalFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(sha1).png" : trimmed
    }
}
