//
//  ForgeLikeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Shared implementation for Forge-family mod loaders (Forge and NeoForge).
enum ForgeLikeLoaderService {
    struct Config {
        let gameLoader: GameLoader
        let labelName: String
        let versionNotFoundErrorKey: String
        let missingVersionErrorKey: String
    }

    static func fetchAllVersions(config: Config, for minecraftVersion: String) async throws -> LoaderVersion {
        do {
            return try await CommonService.fetchAllLoaderVersionsThrowing(
                type: config.gameLoader.modrinthLoaderId,
                minecraftVersion: minecraftVersion,
            )
        } catch {
            throw GlobalError.resource(
                i18nKey: config.versionNotFoundErrorKey,
                level: .notification,
                message: "\(config.labelName) loader version not found for Minecraft \(minecraftVersion)",
            )
        }
    }

    static func fetchSpecificProfile(config: Config, for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
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
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
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
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        AppLog.game.info("Starting to set specified \(config.labelName) loader version: \(loaderVersion)")

        let profile = try await fetchSpecificProfile(config: config, for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)

        let totalDownloads = profile.libraries.count {
            $0.downloads != nil
        }
        let totalProcessors = (profile.processors ?? []).count {
            ($0.sides ?? [AppConstants.EnvironmentTypes.client]).contains(AppConstants.EnvironmentTypes.client)
        }
        let totalTasks = totalDownloads + totalProcessors

        fileManager.onProgressUpdate = { name, completed, _ in onProgressUpdate(name, completed, totalTasks) }

        try await fileManager.downloadForgeJarsThrowing(libraries: profile.libraries)

        if let processors = profile.processors, totalProcessors > 0 {
            try await fileManager.executeProcessors(
                processors: processors,
                librariesDir: librariesDirectory,
                gameVersion: gameVersion,
                data: profile.data,
                gameName: gameInfo.gameName,
            ) { message, current, _ in
                onProgressUpdate(message, totalDownloads + current, totalTasks)
            }
        }

        let classpathString = CommonService.generateClasspath(from: profile, librariesDir: librariesDirectory)
        let mainClass = profile.mainClass
        guard let version = profile.version else {
            throw GlobalError.installation(
                i18nKey: config.missingVersionErrorKey,
                level: .notification,
                message: "\(config.labelName) profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}
