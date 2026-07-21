//
//  ForgeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Forge mod loader versions and profiles.
enum ForgeLoaderService {
    static func fetchAllForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        guard let result = await CommonService.fetchAllLoaderVersions(type: GameLoader.forge.displayName, minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.forge_loader_version_not_found",
                level: .notification,
                message: "Forge loader version not found for Minecraft \(minecraftVersion)",
            )
        }
        return result
    }

    static func fetchSpecificForgeProfile(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        if let cached = DIContainer.shared.core.appCacheManager.get(namespace: GameLoader.forge.displayName, key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: GameLoader.forge.displayName, version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        result.version = loaderVersion
        DIContainer.shared.core.appCacheManager.setSilently(namespace: GameLoader.forge.displayName, key: cacheKey, value: result)

        return result
    }

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void,
    ) async -> (loaderVersion: String, classpath: String, mainClass: String)? {
        do {
            return try await setupWithSpecificVersionThrowing(
                for: gameVersion,
                loaderVersion: loaderVersion,
                gameInfo: gameInfo,
                onProgressUpdate: onProgressUpdate,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to set Forge specified version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return nil
        }
    }

    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void,
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        AppLog.game.info("Starting to set specified Forge loader version: \(loaderVersion)")

        let forgeProfile = try await fetchSpecificForgeProfile(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)

        let totalDownloads = forgeProfile.libraries.count {
            $0.downloads != nil
        }
        let totalProcessors = (forgeProfile.processors ?? []).count {
            ($0.sides ?? [AppConstants.EnvironmentTypes.client]).contains(AppConstants.EnvironmentTypes.client)
        }
        let totalTasks = totalDownloads + totalProcessors

        fileManager.onProgressUpdate = { name, completed, _ in onProgressUpdate(name, completed, totalTasks) }

        await fileManager.downloadForgeJars(libraries: forgeProfile.libraries)

        if let processors = forgeProfile.processors, totalProcessors > 0 {
            try await fileManager.executeProcessors(
                processors: processors,
                librariesDir: librariesDirectory,
                gameVersion: gameVersion,
                data: forgeProfile.data,
                gameName: gameInfo.gameName,
            ) { message, current, _ in
                onProgressUpdate(message, totalDownloads + current, totalTasks)
            }
        }

        let classpathString = CommonService.generateClasspath(from: forgeProfile, librariesDir: librariesDirectory)
        let mainClass = forgeProfile.mainClass
        guard let version = forgeProfile.version else {
            throw GlobalError.resource(
                i18nKey: "error.resource.missing_forge_version",
                level: .notification,
                message: "Forge profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension ForgeLoaderService: ModLoaderHandler { }
