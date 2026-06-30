//
//  GlobalResourceFilter.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Filters compatible games for a resource by checking version support and installation state.
/// - Parameters:
///   - detail: The project detail containing supported versions and loaders.
///   - gameRepository: The game repository for local game data.
///   - resourceType: The type of resource.
///   - projectId: The project identifier.
/// - Returns: The game versions compatible with and not already containing the resource.
func filterCompatibleGames(
    detail: ModrinthProjectDetail,
    gameRepository: GameRepository,
    resourceType: String,
    projectId: String,
) async -> [GameVersionInfo] {
    let supportedVersions = Set(detail.gameVersions)
    let supportedLoaders = Set(detail.loaders.map { $0.lowercased() })
    let resourceTypeLowercased = resourceType.lowercased()

    // Filter locally compatible games by version and loader support.
    let compatibleGames = gameRepository.games.compactMap { game -> GameVersionInfo? in
        let localLoader = game.modLoader.lowercased()
        let match: Bool = {
            switch (resourceTypeLowercased, localLoader) {
            case (ResourceType.datapack.rawValue, GameLoader.vanilla.displayName):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(ResourceType.datapack.rawValue)
            case (ResourceType.shader.rawValue, let loader) where loader != GameLoader.vanilla.displayName:
                return supportedVersions.contains(game.gameVersion)
            case (ResourceType.resourcepack.rawValue, GameLoader.vanilla.displayName):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("minecraft")
            case (ResourceType.resourcepack.rawValue, _),
                 (ResourceType.minecraftJavaServer.rawValue, _):
                return supportedVersions.contains(game.gameVersion)
            default:
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(localLoader)
            }
        }()
        return match ? game : nil
    }

    // Check installation state using hashes from all compatible versions.
    return await withTaskGroup(of: GameVersionInfo?.self) { group in
        for game in compatibleGames {
            group.addTask {
                // Determine the resource installation directory for this game.
                let resourceDir =
                    AppPaths.resourceDirectory(for: resourceType, gameName: game.gameName)
                    ?? AppPaths.modsDirectory(gameName: game.gameName)

                // Check whether the resource is already installed using hash matching.
                let isInstalled = await ModrinthService.isProjectInstalledByAnyCompatibleVersion(
                    projectId: projectId,
                    selectedVersions: [game.gameVersion],
                    selectedLoaders: [game.modLoader],
                    type: resourceType,
                    modsDir: resourceDir,
                )

                if isInstalled {
                    return nil
                }

                return game
            }
        }

        var results: [GameVersionInfo] = []
        for await game in group {
            if let game {
                results.append(game)
            }
        }
        return results
    }
}
