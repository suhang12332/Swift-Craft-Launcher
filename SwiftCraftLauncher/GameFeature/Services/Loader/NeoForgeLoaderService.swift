//
//  NeoForgeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages NeoForge mod loader versions and profiles.
enum NeoForgeLoaderService {
    static let config = ForgeLikeLoaderService.Config(
        gameLoader: .neoforge,
        labelName: GameLoader.neoforge.labelName,
        versionNotFoundErrorKey: "error.resource.neoforge_loader_version_not_found",
        missingVersionErrorKey: "error.resource.neoforge_missing_version",
    )

    static func fetchAllNeoForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        try await ForgeLikeLoaderService.fetchAllVersions(config: config, for: minecraftVersion)
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

extension NeoForgeLoaderService: ModLoaderHandler { }
