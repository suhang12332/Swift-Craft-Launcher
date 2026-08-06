//
//  ForgeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Forge mod loader versions and profiles.
enum ForgeLoaderService {
    private static let config = ForgeLikeLoaderService.Config(
        gameLoader: .forge,
        displayName: "Forge",
        versionNotFoundErrorKey: "error.resource.forge_loader_version_not_found",
        missingVersionErrorKey: "error.resource.missing_forge_version",
    )

    static func fetchAllForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        try await ForgeLikeLoaderService.fetchAllVersions(config: config, for: minecraftVersion)
    }

    static func fetchSpecificForgeProfile(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        try await ForgeLikeLoaderService.fetchSpecificProfile(config: config, for: minecraftVersion, loaderVersion: loaderVersion)
    }

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        await ForgeLikeLoaderService.setupWithSpecificVersion(
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
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        try await ForgeLikeLoaderService.setupWithSpecificVersionThrowing(
            config: config,
            for: gameVersion,
            loaderVersion: loaderVersion,
            gameInfo: gameInfo,
            onProgressUpdate: onProgressUpdate,
        )
    }
}

extension ForgeLoaderService: ModLoaderHandler { }
