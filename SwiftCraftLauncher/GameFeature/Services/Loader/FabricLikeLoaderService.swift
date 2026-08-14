//
//  FabricLikeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared implementation for Fabric-family mod loaders (Fabric and Quilt).
enum FabricLikeLoaderService {
    struct Config {
        let gameLoader: GameLoader
    }

    static func fetchSpecificLoaderVersion(config: Config, for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let namespace = "\(config.gameLoader.displayName)-\(minecraftVersion)-\(loaderVersion)"

        if let cached = DIContainer.shared.core.appCacheManager.get(
            namespace: namespace,
            key: "profile",
            as: ModrinthLoader.self,
            directory: AppPaths.loaderCache,
        ) {
            return cached
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: config.gameLoader.modrinthLoaderId, version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        result.version = loaderVersion
        DIContainer.shared.core.appCacheManager.setSilently(
            namespace: namespace,
            key: "profile",
            value: result,
            directory: AppPaths.loaderCache,
        )

        return result
    }
}
