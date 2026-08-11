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
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        if let cached = DIContainer.shared.core.appCacheManager.get(namespace: config.gameLoader.displayName, key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: config.gameLoader.modrinthLoaderId, version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        result.version = loaderVersion
        DIContainer.shared.core.appCacheManager.setSilently(namespace: config.gameLoader.displayName, key: cacheKey, value: result)

        return result
    }
}
