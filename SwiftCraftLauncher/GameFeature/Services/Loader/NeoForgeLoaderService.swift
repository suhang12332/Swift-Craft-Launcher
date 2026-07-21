//
//  NeoForgeLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages NeoForge mod loader versions and profiles.
enum NeoForgeLoaderService {
    static func fetchAllNeoForgeVersions(for minecraftVersion: String) async throws -> LoaderVersion {
        guard let result = await CommonService.fetchAllLoaderVersions(type: "neo", minecraftVersion: minecraftVersion) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.neoforge_loader_version_not_found",
                level: .notification,
                message: "NeoForge loader version not found for Minecraft \(minecraftVersion)",
            )
        }
        return result
    }

    static func fetchSpecificNeoForgeProfile(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        if let cached = DIContainer.shared.core.appCacheManager.get(namespace: GameLoader.neoforge.displayName, key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: "neo", version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        result.version = loaderVersion
        DIContainer.shared.core.appCacheManager.setSilently(namespace: GameLoader.neoforge.displayName, key: cacheKey, value: result)

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
            AppLog.game.error("Failed to set NeoForge specified version: \(globalError.localizedDescription)")
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
        AppLog.game.info("Starting to set specified NeoForge loader version: \(loaderVersion)")

        let neoForgeProfile = try await fetchSpecificNeoForgeProfile(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)

        let totalDownloads = neoForgeProfile.libraries.count { $0.downloads != nil }
        let totalProcessors = (neoForgeProfile.processors ?? []).count {
            ($0.sides ?? [AppConstants.EnvironmentTypes.client]).contains(AppConstants.EnvironmentTypes.client)
        }
        let totalTasks = totalDownloads + totalProcessors

        fileManager.onProgressUpdate = { name, completed, _ in onProgressUpdate(name, completed, totalTasks) }

        await fileManager.downloadForgeJars(libraries: neoForgeProfile.libraries)

        if let processors = neoForgeProfile.processors, totalProcessors > 0 {
            try await fileManager.executeProcessors(
                processors: processors,
                librariesDir: librariesDirectory,
                gameVersion: gameVersion,
                data: neoForgeProfile.data,
                gameName: gameInfo.gameName,
            ) { message, current, _ in
                onProgressUpdate(message, totalDownloads + current, totalTasks)
            }
        }

        let classpathString = CommonService.generateClasspath(from: neoForgeProfile, librariesDir: librariesDirectory)
        let mainClass = neoForgeProfile.mainClass

        guard let version = neoForgeProfile.version else {
            throw GlobalError.resource(
                i18nKey: "error.resource.neoforge_missing_version",
                level: .notification,
                message: "NeoForge profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }

        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension NeoForgeLoaderService: ModLoaderHandler { }
