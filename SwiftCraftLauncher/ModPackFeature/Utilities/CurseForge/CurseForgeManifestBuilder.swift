//
//  CurseForgeManifestBuilder.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Builds CurseForge-format mod pack manifest files.
///
/// Constructs the `manifest.json` content and metadata structures
/// required by the CurseForge mod pack format.
enum CurseForgeManifestBuilder {
    /// A file entry in the CurseForge manifest referencing a project and file ID.
    struct ManifestFile: Codable {
        let projectID: Int
        let fileID: Int
        let required: Bool
        let isLocked: Bool
    }

    private struct Manifest: Codable {
        let minecraft: Minecraft
        let manifestType: String
        let manifestVersion: Int
        let name: String
        let version: String
        let author: String
        let files: [ManifestFile]
        let overrides: String
    }

    private struct Minecraft: Codable {
        let version: String
        let modLoaders: [ModLoader]
    }

    private struct ModLoader: Codable {
        let id: String
        let primary: Bool
    }

    /// Builds the manifest JSON string for a CurseForge mod pack.
    ///
    /// - Parameters:
    ///   - gameInfo: The game version and mod loader information.
    ///   - modPackName: The name of the mod pack.
    ///   - modPackVersion: The version string of the mod pack.
    ///   - files: The list of manifest file entries.
    /// - Returns: A JSON string representing the manifest.
    static func build(
        gameInfo: GameVersionInfo,
        modPackName: String,
        modPackVersion: String,
        files: [ManifestFile],
    ) throws -> String {
        let minecraft = Minecraft(
            version: gameInfo.gameVersion,
            modLoaders: buildModLoaders(gameInfo: gameInfo),
        )

        let manifest = Manifest(
            minecraft: minecraft,
            manifestType: "minecraftModpack",
            manifestVersion: 1,
            name: modPackName,
            version: modPackVersion,
            author: "",
            files: files,
            overrides: "overrides",
        )

        let data = try JSONEncoder.prettySorted.encode(manifest)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Builds the mod loader entries for the manifest.
    private static func buildModLoaders(gameInfo: GameVersionInfo) -> [ModLoader] {
        let loaderType = gameInfo.modLoader.lowercased()
        guard loaderType != GameLoader.vanilla.displayName else { return [] }

        let loaderVersion = gameInfo.modVersion
        if !loaderVersion.isEmpty {
            return [ModLoader(id: "\(loaderType)-\(loaderVersion)", primary: true)]
        }
        return [ModLoader(id: loaderType, primary: true)]
    }
}

private extension JSONEncoder {
    static var prettySorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
