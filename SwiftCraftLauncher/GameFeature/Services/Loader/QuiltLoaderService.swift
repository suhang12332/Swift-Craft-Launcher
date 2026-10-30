//
//  QuiltLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Quilt mod loader versions and profiles.
enum QuiltLoaderService {
    static let config = FabricLikeLoaderService.Config(
        gameLoader: .quilt,
        labelName: GameLoader.quilt.labelName,
        missingVersionErrorKey: "error.resource.quilt_missing_version",
    )

    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        try await FabricLikeLoaderService.fetchSpecificLoaderVersion(config: config, for: minecraftVersion, loaderVersion: loaderVersion)
    }

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async -> ModLoaderSetupResult? {
        await FabricLikeLoaderService.setupWithSpecificVersion(
            config: config,
            for: gameVersion,
            loaderVersion: loaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: onProgressUpdate,
        )
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

extension QuiltLoaderService: ModLoaderHandler { }
