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

        return try await CommonService.fetchLoaderProfile(
            loaderId: config.gameLoader.modrinthLoaderId,
            loaderVersion: loaderVersion,
            namespace: namespace,
            gameVersion: minecraftVersion,
        )
    }
}
