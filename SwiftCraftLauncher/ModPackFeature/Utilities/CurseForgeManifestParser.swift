//
//  CurseForgeManifestParser.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Parses a CurseForge modpack's manifest.json file.
enum CurseForgeManifestParser {
    /// Parses the manifest.json file within an extracted CurseForge modpack.
    /// - Parameter extractedPath: The path to the extracted modpack directory.
    /// - Returns: The parsed Modrinth index information, or `nil` if parsing fails.
    static func parseManifest(extractedPath: URL) async -> ModrinthIndexInfo? {
        do {
            let manifestPath = extractedPath.appendingPathComponent("manifest.json")

            AppLog.modPack.info("Attempting to parse CurseForge manifest.json: \(manifestPath.path)")

            guard FileManager.default.fileExists(atPath: manifestPath.path) else {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: extractedPath,
                        includingPropertiesForKeys: nil,
                    )
                    AppLog.modPack.info("Extracted directory contents: \(contents.map(\.lastPathComponent))")
                } catch {
                    AppLog.modPack.error("Failed to list extracted directory contents: \(error.localizedDescription)")
                }

                AppLog.modPack.error("manifest.json not found in CurseForge modpack")
                return nil
            }

            let fileAttributes = try FileManager.default.attributesOfItem(atPath: manifestPath.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            AppLog.modPack.info("manifest.json file size: \(fileSize) bytes")

            guard fileSize > 0 else {
                AppLog.modPack.error("manifest.json file is empty")
                return nil
            }

            let manifestData = try Data(contentsOf: manifestPath)
            AppLog.modPack.info("Successfully read manifest.json data, size: \(manifestData.count) bytes")

            let manifest = try JSONDecoder().decode(CurseForgeManifest.self, from: manifestData)

            let loaderInfo = determineLoaderInfo(from: manifest.minecraft.modLoaders)

            let modPackVersion = manifest.version ?? generateAutoVersion(
                modPackName: manifest.name,
                gameVersion: manifest.minecraft.version,
                loaderInfo: loaderInfo,
            )

            let modrinthInfo = await convertToModrinthFormat(
                manifest: manifest,
                loaderInfo: loaderInfo,
                generatedVersion: modPackVersion,
            )

            AppLog.modPack.info("Successfully parsed CurseForge manifest.json: \(manifest.name) v\(modPackVersion)")
            if manifest.version == nil {
                AppLog.modPack.info("⚠️ Modpack missing version field, auto-generated version: \(modPackVersion)")
            }
            AppLog.modPack.info("Game version: \(manifest.minecraft.version), loader: \(loaderInfo.type) \(loaderInfo.version)")
            AppLog.modPack.info("File count: \(manifest.files.count)")

            return modrinthInfo
        } catch {
            AppLog.modPack.error("Failed to parse CurseForge manifest.json: \(error)")

            if let jsonError = error as? DecodingError {
                AppLog.modPack.error("JSON parse error: \(jsonError)")
            }

            return nil
        }
    }

    /// Determines the loader type and version from a list of mod loaders.
    /// - Parameter modLoaders: The list of mod loaders from the manifest.
    /// - Returns: A tuple containing the loader type and version.
    private static func determineLoaderInfo(from modLoaders: [CurseForgeModLoader]) -> (type: String, version: String) {
        guard let primaryLoader = modLoaders.first(where: { $0.primary }) ?? modLoaders.first else {
            return (GameLoader.vanilla.displayName, "unknown")
        }

        let loaderId = primaryLoader.id.lowercased()

        let components = loaderId.split(separator: "-")

        if components.count >= 2 {
            let loaderType = String(components[0])
            let loaderVersion = components.dropFirst().joined(separator: "-")

            let normalizedType = normalizeLoaderType(loaderType)

            return (normalizedType, loaderVersion)
        } else {
            if loaderId.contains(GameLoader.forge.displayName) {
                return (GameLoader.forge.displayName, "unknown")
            } else if loaderId.contains(GameLoader.fabric.displayName) {
                return (GameLoader.fabric.displayName, "unknown")
            } else if loaderId.contains(GameLoader.quilt.rawValue) {
                return (GameLoader.quilt.rawValue, "unknown")
            } else if loaderId.contains(GameLoader.neoforge.displayName) {
                return (GameLoader.neoforge.displayName, "unknown")
            } else {
                return (GameLoader.vanilla.displayName, "unknown")
            }
        }
    }

    /// Normalizes a loader type string to its canonical display name.
    /// - Parameter loaderType: The raw loader type string.
    /// - Returns: The normalized loader type.
    private static func normalizeLoaderType(_ loaderType: String) -> String {
        switch loaderType.lowercased() {
        case GameLoader.forge.displayName:
            return GameLoader.forge.displayName
        case GameLoader.fabric.displayName:
            return GameLoader.fabric.displayName
        case GameLoader.quilt.rawValue:
            return GameLoader.quilt.rawValue
        case GameLoader.neoforge.displayName:
            return GameLoader.neoforge.displayName
        default:
            return loaderType.lowercased()
        }
    }

    /// Generates an automatic version string for a modpack.
    /// - Parameters:
    ///   - modPackName: The name of the modpack.
    ///   - gameVersion: The Minecraft game version.
    ///   - loaderInfo: The mod loader information.
    /// - Returns: A generated version string in the format `gameVersion-loaderType-date`.
    private static func generateAutoVersion(
        modPackName _: String,
        gameVersion: String,
        loaderInfo: (type: String, version: String),
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())

        let autoVersion = "\(gameVersion)-\(loaderInfo.type)-\(dateString)"

        AppLog.modPack.info("Auto-generated modpack version: \(autoVersion)")
        return autoVersion
    }

    /// Converts a CurseForge manifest to Modrinth index format.
    /// - Parameters:
    ///   - manifest: The CurseForge manifest to convert.
    ///   - loaderInfo: The mod loader information.
    ///   - generatedVersion: The version string (used when the manifest lacks a version field).
    /// - Returns: A Modrinth index info with placeholder file entries.
    private static func convertToModrinthFormat(
        manifest: CurseForgeManifest,
        loaderInfo: (type: String, version: String),
        generatedVersion: String,
    ) async -> ModrinthIndexInfo {
        AppLog.modPack.info("Converting CurseForge format to Modrinth format, mod count: \(manifest.files.count)")

        var modrinthFiles: [ModrinthIndexFile] = []

        for file in manifest.files {
            let placeholderPath = "mods/curseforge_\(file.projectID)_\(file.fileID).jar"

            modrinthFiles.append(ModrinthIndexFile(
                path: placeholderPath,
                hashes: ModrinthIndexFileHashes(from: [:]),
                downloads: [],
                fileSize: 0,
                env: nil,
                source: .curseforge,
                curseForgeProjectId: file.projectID,
                curseForgeFileId: file.fileID,
            ))
        }

        AppLog.modPack.info("Quick conversion completed, will fetch details during download phase")

        return ModrinthIndexInfo(
            gameVersion: manifest.minecraft.version,
            loaderType: loaderInfo.type,
            loaderVersion: loaderInfo.version,
            modPackName: manifest.name,
            modPackVersion: generatedVersion,
            summary: "",
            files: modrinthFiles,
            dependencies: [],
            source: .curseforge,
        )
    }
}
