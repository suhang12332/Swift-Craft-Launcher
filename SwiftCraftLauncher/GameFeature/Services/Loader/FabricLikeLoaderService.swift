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
        let labelName: String
        let missingVersionErrorKey: String
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

    static func setupWithSpecificVersion(
        config: Config,
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async -> ModLoaderSetupResult? {
        do {
            return try await setupWithSpecificVersionThrowing(
                config: config,
                for: gameVersion,
                loaderVersion: loaderVersion,
                gameInfo: gameInfo,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to set \(config.labelName) specified version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return nil
        }
    }

    static func setupWithSpecificVersionThrowing(
        config: Config,
        for gameVersion: String,
        loaderVersion: String,
        gameInfo _: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async throws -> ModLoaderSetupResult {
        AppLog.game.info("Starting to set specified \(config.labelName) loader version: \(loaderVersion)")

        let profile = try await fetchSpecificLoaderVersion(config: config, for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        try await fileManager.downloadFabricJarsThrowing(libraries: profile.libraries)

        let classpathString = CommonService.generateFabricClasspath(from: profile, librariesDir: librariesDirectory)
        let mainClass = profile.mainClass
        guard let version = profile.version else {
            throw GlobalError.installation(
                i18nKey: config.missingVersionErrorKey,
                level: .notification,
                message: "\(config.labelName) profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }
        return ModLoaderSetupResult(
            loaderVersion: version,
            classpath: classpathString,
            mainClass: mainClass,
            gameArguments: profile.arguments.game ?? [],
            jvmArguments: profile.arguments.jvm ?? [],
        )
    }
}
