//
//  QuiltLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Quilt mod loader versions and profiles.
enum QuiltLoaderService {
    private static let config = FabricLikeLoaderService.Config(gameLoader: .quilt)

    static func fetchAllQuiltLoaders(for minecraftVersion: String) async -> [QuiltLoaderResponse] {
        do {
            return try await fetchAllQuiltLoadersThrowing(for: minecraftVersion)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to get Quilt loader version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return []
        }
    }

    static func fetchAllQuiltLoadersThrowing(for minecraftVersion: String) async throws -> [QuiltLoaderResponse] {
        let url = URLConfig.API.Quilt.loaderBase.appendingPathComponent(minecraftVersion)
        let data = try await APIClient.get(url: url)
        let decoder = JSONDecoder()
        let allLoaders = try decoder.decode([QuiltLoaderResponse].self, from: data)
        return allLoaders.filter { !$0.loader.version.lowercased().contains("beta") && !$0.loader.version.lowercased().contains("pre") }
    }

    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        try await FabricLikeLoaderService.fetchSpecificLoaderVersion(config: config, for: minecraftVersion, loaderVersion: loaderVersion)
    }

    static func setupWithSpecificVersion(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
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
            AppLog.game.error("Failed to set Quilt specified version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return nil
        }
    }

    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo _: GameVersionInfo,
        onProgressUpdate: @escaping @Sendable (String, Int, Int) -> Void,
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        AppLog.game.info("Starting to set specified Quilt loader version: \(loaderVersion)")

        let quiltProfile = try await fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        await fileManager.downloadFabricJars(libraries: quiltProfile.libraries)

        let classpathString = CommonService.generateFabricClasspath(from: quiltProfile, librariesDir: librariesDirectory)
        let mainClass = quiltProfile.mainClass
        guard let version = quiltProfile.version else {
            throw GlobalError.installation(
                i18nKey: "error.resource.quilt_missing_version",
                level: .notification,
                message: "Quilt profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension QuiltLoaderService: ModLoaderHandler { }
