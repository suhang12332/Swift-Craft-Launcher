//
//  ModrinthIndexBuilder.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Builds the `modrinth.index.json` structure for Modrinth modpacks.
enum ModrinthIndexBuilder {

    /// Builds a JSON string representing the Modrinth index file.
    /// - Parameters:
    ///   - gameInfo: The game version and mod loader information.
    ///   - modPackName: The display name of the modpack.
    ///   - modPackVersion: The version identifier of the modpack.
    ///   - summary: An optional description of the modpack.
    ///   - files: The list of files to include in the index.
    /// - Returns: A JSON string.
    static func build(
        gameInfo: GameVersionInfo,
        modPackName: String,
        modPackVersion: String,
        summary: String?,
        files: [ModrinthIndexFile]
    ) async throws -> String {
        let gameVersion = gameInfo.gameVersion
        let loaderType = gameInfo.modLoader.lowercased()

        Logger.shared.info("导出整合包 - 加载器类型: \(loaderType), 版本: \(gameInfo.modVersion)")

        let dependencies = buildDependencies(
            gameVersion: gameVersion,
            loaderType: loaderType,
            loaderVersion: gameInfo.modVersion
        )

        var jsonDict: [String: Any] = [
            "formatVersion": 1,
            "game": "minecraft",
            "versionId": modPackVersion,
            "name": modPackName,
        ]

        if let summary = summary {
            jsonDict["summary"] = summary
        }

        var filesArray: [[String: Any]] = []
        for file in files {
            var fileDict: [String: Any] = [
                "path": file.path,
                "hashes": [
                    "sha1": file.hashes.sha1 ?? "",
                    "sha512": file.hashes.sha512 ?? "",
                ],
                "downloads": file.downloads,
                "fileSize": file.fileSize,
            ]

            if let env = file.env {
                var envDict: [String: String] = [:]
                if let client = env.client {
                    envDict["client"] = client
                }
                if let server = env.server {
                    envDict["server"] = server
                }
                if !envDict.isEmpty {
                    fileDict["env"] = envDict
                }
            }

            filesArray.append(fileDict)
        }
        jsonDict["files"] = filesArray

        var depsDict: [String: Any] = [:]
        if let minecraft = dependencies.minecraft {
            depsDict["minecraft"] = minecraft
        }
        if let forgeLoader = dependencies.forgeLoader {
            depsDict["forge-loader"] = forgeLoader
        }
        if let fabricLoader = dependencies.fabricLoader {
            depsDict["fabric-loader"] = fabricLoader
        }
        if let quiltLoader = dependencies.quiltLoader {
            depsDict["quilt-loader"] = quiltLoader
        }
        if let neoforgeLoader = dependencies.neoforgeLoader {
            depsDict["neoforge-loader"] = neoforgeLoader
        }
        jsonDict["dependencies"] = depsDict

        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonDict,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    /// Builds the dependencies dictionary for the specified loader type.
    private static func buildDependencies(
        gameVersion: String,
        loaderType: String,
        loaderVersion: String?
    ) -> ModrinthIndexDependencies {
        switch loaderType {
        case GameLoader.forge.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: loaderVersion,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.fabric.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: loaderVersion,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.quilt.rawValue:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: loaderVersion,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.neoforge.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: loaderVersion,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        default:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        }
    }
}
