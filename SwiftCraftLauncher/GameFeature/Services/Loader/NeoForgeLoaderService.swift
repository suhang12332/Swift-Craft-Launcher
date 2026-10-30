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
        missingVersionErrorKey: "error.resource.neoforge_missing_version",
    )

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async -> ModLoaderSetupResult? {
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
    ) async throws -> ModLoaderSetupResult {
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
