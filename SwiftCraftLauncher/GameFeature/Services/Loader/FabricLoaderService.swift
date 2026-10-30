//
//  FabricLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Fabric mod loader versions and profiles.
enum FabricLoaderService {
    static let config = FabricLikeLoaderService.Config(
        gameLoader: .fabric,
        labelName: GameLoader.fabric.labelName,
        missingVersionErrorKey: "error.validation.fabric_loader_version_missing",
    )

    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        try await FabricLikeLoaderService.fetchSpecificLoaderVersion(config: config, for: minecraftVersion, loaderVersion: loaderVersion)
    }

    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async throws -> ModLoaderSetupResult {
        try await FabricLikeLoaderService.setupWithSpecificVersionThrowing(
            config: config,
            for: gameVersion,
            loaderVersion: loaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: onProgressUpdate,
        )
    }
}

extension FabricLoaderService: ModLoaderHandler { }
