//
//  GameNameGenerator.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

/// Generates default game instance names for various installation types.
enum GameNameGenerator {
    /// Generates a default game name for a ModPack download.
    /// - Parameters:
    ///   - projectTitle: The project title, or `nil` to use a default.
    ///   - gameVersion: The Minecraft version string.
    ///   - includeTimestamp: Whether to append a timestamp. Defaults to `true`.
    /// - Returns: A formatted game name.
    static func generateModPackName(
        projectTitle: String?,
        gameVersion: String,
        includeTimestamp: Bool = true
    ) -> String {
        let baseName = "\(projectTitle ?? "ModPack")-\(gameVersion)"

        if includeTimestamp {
            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            return "\(baseName)-\(timestamp)"
        }

        return baseName
    }

    /// Generates a default game name for an imported ModPack.
    /// - Parameters:
    ///   - modPackName: The name of the ModPack.
    ///   - modPackVersion: The version of the ModPack.
    ///   - includeTimestamp: Whether to append a timestamp. Defaults to `true`.
    /// - Returns: A formatted game name.
    static func generateImportName(
        modPackName: String,
        modPackVersion: String,
        includeTimestamp: Bool = true
    ) -> String {
        let baseName = "\(modPackName)-\(modPackVersion)"

        if includeTimestamp {
            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            return "\(baseName)-\(timestamp)"
        }

        return baseName
    }

    /// Generates a default game name for a standard game installation.
    /// - Parameters:
    ///   - gameVersion: The Minecraft version string.
    ///   - modLoader: The mod loader display name.
    ///   - includeTimestamp: Whether to append a timestamp. Defaults to `true`.
    /// - Returns: A formatted game name.
    static func generateGameName(
        gameVersion: String,
        loaderVersion: String,
        modLoader: String,
        includeTimestamp: Bool = true
    ) -> String {
        let baseName: String
        if modLoader.lowercased() == GameLoader.vanilla.displayName {
            baseName = "\(gameVersion)-\(modLoader.lowercased())"
        } else {
            baseName = "\(gameVersion)-\(modLoader.lowercased())-\(loaderVersion)"
        }
        if includeTimestamp {
            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            return "\(baseName)-\(timestamp)"
        }
        return baseName
    }
}
