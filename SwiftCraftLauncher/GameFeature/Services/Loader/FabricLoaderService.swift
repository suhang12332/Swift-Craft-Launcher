//
//  FabricLoaderService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Fetches and manages Fabric mod loader versions and profiles.
enum FabricLoaderService {
    static func fetchAllLoaderVersions(for minecraftVersion: String) async -> [FabricLoader] {
        do {
            return try await fetchAllLoaderVersionsThrowing(for: minecraftVersion)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to get Fabric loader version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return []
        }
    }

    static func fetchAllLoaderVersionsThrowing(for minecraftVersion: String) async throws -> [FabricLoader] {
        let url = URLConfig.API.Fabric.loader.appendingPathComponent(minecraftVersion)
        let data = try await APIClient.get(url: url)

        var result: [FabricLoader] = []
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in jsonArray {
                    let singleData = try JSONSerialization.data(withJSONObject: item)
                    let decoder = JSONDecoder()
                    if let loader = try? decoder.decode(FabricLoader.self, from: singleData) {
                        result.append(loader)
                    }
                }
            }
            return result
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.fabric_loader_parse_failed",
                level: .notification,
                message: "failed to parse Fabric loader versions for Minecraft \(minecraftVersion), error: \(error.localizedDescription)",
            )
        }
    }

    static func fetchSpecificLoaderVersion(for minecraftVersion: String, loaderVersion: String) async throws -> ModrinthLoader {
        let cacheKey = "\(minecraftVersion)-\(loaderVersion)"

        if let cached = DIContainer.shared.core.appCacheManager.get(namespace: GameLoader.fabric.displayName, key: cacheKey, as: ModrinthLoader.self) {
            return cached
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: GameLoader.fabric.displayName, version: loaderVersion)
        let data = try await APIClient.get(url: url)

        var result = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        result.version = loaderVersion
        result = CommonService.processGameVersionPlaceholders(loader: result, gameVersion: minecraftVersion)
        DIContainer.shared.core.appCacheManager.setSilently(namespace: GameLoader.fabric.displayName, key: cacheKey, value: result)
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
            AppLog.game.error("Failed to set Fabric specified version: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return nil
        }
    }

    static func setupWithSpecificVersionThrowing(
        for gameVersion: String,
        loaderVersion: String,
        gameInfo _: GameVersionInfo,
        onProgressUpdate: @escaping (String, Int, Int) -> Void,
    ) async throws -> (loaderVersion: String, classpath: String, mainClass: String) {
        AppLog.game.info("Starting to set specified Fabric loader version: \(loaderVersion)")

        let fabricProfile = try await fetchSpecificLoaderVersion(for: gameVersion, loaderVersion: loaderVersion)
        let librariesDirectory = AppPaths.librariesDirectory
        let fileManager = CommonFileManager(librariesDir: librariesDirectory)
        fileManager.onProgressUpdate = onProgressUpdate

        await fileManager.downloadFabricJars(libraries: fabricProfile.libraries)

        let classpathString = CommonService.generateFabricClasspath(from: fabricProfile, librariesDir: librariesDirectory)
        let mainClass = fabricProfile.mainClass
        guard let version = fabricProfile.version else {
            throw GlobalError.validation(
                i18nKey: "error.validation.fabric_loader_version_missing",
                level: .notification,
                message: "Fabric profile missing version for game \(gameVersion), loaderVersion \(loaderVersion)",
            )
        }
        return (loaderVersion: version, classpath: classpathString, mainClass: mainClass)
    }
}

extension FabricLoaderService: ModLoaderHandler { }
