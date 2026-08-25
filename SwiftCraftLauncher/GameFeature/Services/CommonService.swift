//
//  CommonService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides shared utilities for mod loader version management and classpath generation.
enum CommonService {
    static func compatibleVersionsThrowing(
        for loader: String,
        includeSnapshots: Bool = false,
    ) async throws -> [String] {
        var result: [String] = []
        switch loader.lowercased() {
        case GameLoader.fabric.displayName, GameLoader.forge.displayName, GameLoader.quilt.rawValue, GameLoader.neoforge.displayName:
            let loaderType =
                loader.lowercased() == GameLoader.neoforge.displayName ? "neo" : loader.lowercased()
            let loaderVersions = try await fetchAllVersionThrowing(
                type: loaderType,
            )
            let filteredVersions = loaderVersions.map(\.id)
                .filter { version in
                    let components = version.components(separatedBy: ".")
                    return components.allSatisfy {
                        $0.rangeOfCharacter(
                            from: CharacterSet.decimalDigits.inverted,
                        ) == nil
                    }
                }
            let sortResult = CommonUtil.sortMinecraftVersions(filteredVersions)
            result = CommonUtil.versionsAtLeast(sortResult)
        default:
            let gameVersions = try await ModrinthService.fetchGameVersionsThrowing(
                includeSnapshots: includeSnapshots,
            )
            let versionNames = gameVersions
                .map { version in
                    let cacheKey = "version_time_\(version.version)"
                    let formattedTime = CommonUtil.formatRelativeTime(
                        version.date,
                    )
                    do {
                        try DIContainer.shared.core.appCacheManager.set(
                            namespace: "version_time",
                            key: cacheKey,
                            value: formattedTime,
                        )
                    } catch {
                        DIContainer.shared.core.errorHandler.handle(error)
                    }
                    return version.version
                }
            result = CommonUtil.versionsAtLeast(versionNames)
        }
        return result
    }

    static func generateClasspath(
        from loader: ModrinthLoader,
        librariesDir: URL,
    ) -> String {
        let jarPaths: [String] = loader.libraries.compactMap { lib in
            guard lib.includeInClasspath else { return nil }
            guard let downloads = lib.downloads else { return nil }
            let artifact = downloads.artifact
            guard let artifactPath = artifact.path else { return nil }
            return librariesDir.appendingPathComponent(artifactPath).path
        }
        return jarPaths.joined(separator: ":")
    }

    static func fetchAllLoaderVersionsThrowing(
        type: String,
        minecraftVersion: String,
    ) async throws -> LoaderVersion {
        let manifest = try await fetchAllVersionThrowing(type: type)

        let filteredVersions = manifest.filter { $0.id == minecraftVersion }

        guard let firstVersion = filteredVersions.first else {
            throw GlobalError.resource(
                i18nKey: "error.resource.loader_version_not_found",
                level: .notification,
                message: "loader version '\(minecraftVersion)' not found in type '\(type)'",
            )
        }

        return firstVersion
    }

    static func fetchAllVersionThrowing(
        type: String,
    ) async throws -> [LoaderVersion] {
        let manifestURL = URLConfig.API.Modrinth.loaderManifest(loader: type)
        let manifestData = try await APIClient.get(url: manifestURL)

        do {
            let result = try JSONDecoder().decode(
                ModrinthLoaderVersion.self,
                from: manifestData,
            )

            if type == "neo" {
                return result.gameVersions
            } else {
                return result.gameVersions.filter(\.stable)
            }
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.version_manifest_parse_failed",
                level: .notification,
                message: "failed to parse version manifest for type '\(type)', error: \(error.localizedDescription)",
            )
        }
    }

    static func convertMavenCoordinateToPath(_ coordinate: String) -> String {
        if coordinate.contains("@") {
            return convertMavenCoordinateWithAtSymbol(coordinate)
        }

        if let relativePath = mavenCoordinateToRelativePath(coordinate) {
            return AppPaths.librariesDirectory.appendingPathComponent(
                relativePath,
            ).path
        }

        return coordinate
    }

    static func parseMavenCoordinateWithAtSymbol(
        _ coordinate: String,
    ) -> String {
        let parts = coordinate.components(separatedBy: ":")
        guard parts.count >= 3 else { return coordinate }

        let groupId = parts[0]
        let artifactId = parts[1]

        var version = parts[2]
        var classifier = ""
        var classifierName = ""

        if version.contains("@") {
            let versionParts = version.components(separatedBy: "@")
            if versionParts.count >= 2 {
                version = versionParts[0]
                classifier = versionParts[1]
            }
        } else if parts.count > 3 {
            let classifierPart = parts[3]
            if classifierPart.contains("@") {
                let classifierParts = classifierPart.components(
                    separatedBy: "@",
                )
                if classifierParts.count >= 2 {
                    classifierName = classifierParts[0]
                    classifier = classifierParts[1]
                }
            } else {
                classifier = classifierPart
            }
        }

        let classifierSuffix = classifierName.isEmpty ? "" : "-\(classifierName)"
        let extensionSuffix = classifier.isEmpty ? ".\(AppConstants.FileExtensions.jar)" : ".\(classifier)"
        let fileName = "\(artifactId)-\(version)\(classifierSuffix)\(extensionSuffix)"

        let groupPath = groupId.replacingOccurrences(of: ".", with: "/")
        return "\(groupPath)/\(artifactId)/\(version)/\(fileName)"
    }

    static func convertMavenCoordinateWithAtSymbol(
        _ coordinate: String,
    ) -> String {
        let relativePath = parseMavenCoordinateWithAtSymbol(coordinate)

        return AppPaths.librariesDirectory.appendingPathComponent(relativePath)
            .path
    }

    static func mavenCoordinateToRelativePath(_ coordinate: String) -> String? {
        let parts = coordinate.split(separator: ":")
        guard parts.count >= 3 else { return nil }

        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]

        var version = ""
        var classifier: String?

        if parts.count == 3 {
            version = String(parts[2])
        } else if parts.count == 4 {
            version = String(parts[2])
            classifier = String(parts[3])
        } else if parts.count == 5 {
            version = String(parts[4])
            classifier = String(parts[3])
        }

        if let classifier {
            return
                "\(group)/\(artifact)/\(version)/\(artifact)-\(version)-\(classifier).jar"
        } else {
            return "\(group)/\(artifact)/\(version)/\(artifact)-\(version).jar"
        }
    }

    static func mavenCoordinateToRelativePathForURL(_ coordinate: String) -> String {
        if coordinate.contains("@") {
            return parseMavenCoordinateWithAtSymbol(coordinate)
        }

        if let relativePath = mavenCoordinateToRelativePath(coordinate) {
            return relativePath
        }

        return coordinate
    }

    static func mavenCoordinateToURL(lib: ModrinthLoaderLibrary) -> URL? {
        let relativePath = mavenCoordinateToRelativePathForURL(lib.name)
        return lib.url?.appendingPathComponent(relativePath)
    }

    static func mavenCoordinateToURL(_ coordinate: String, baseURL: URL) -> URL {
        let relativePath = mavenCoordinateToRelativePathForURL(coordinate)
        return baseURL.appendingPathComponent(relativePath)
    }

    static func generateFabricClasspath(
        from loader: ModrinthLoader,
        librariesDir: URL,
    ) -> String {
        let jarPaths = loader.libraries.compactMap { coordinate -> String? in
            guard let relPath = mavenCoordinateToRelativePath(coordinate.name)
            else { return nil }
            return librariesDir.appendingPathComponent(relPath).path
        }
        return jarPaths.joined(separator: ":")
    }

    static func processGameVersionPlaceholders(
        loader: ModrinthLoader,
        gameVersion: String,
    ) -> ModrinthLoader {
        var processedLoader = loader

        processedLoader.libraries = loader.libraries.map { library in
            var processedLibrary = library

            processedLibrary.name = library.name.replacingOccurrences(
                of: "${modrinth.gameVersion}",
                with: gameVersion,
            )

            return processedLibrary
        }
        return processedLoader
    }

    /// Fetches a mod loader profile, caching the raw Modrinth JSON data.
    ///
    /// Caching the raw response (rather than the decoded object) preserves the
    /// conditional rule structure so it can be re-evaluated on every decode.
    /// - Parameters:
    ///   - loaderId: The Modrinth loader identifier (e.g. "fabric").
    ///   - loaderVersion: The specific loader version.
    ///   - namespace: The cache namespace.
    ///   - gameVersion: The Minecraft game version.
    /// - Returns: The processed `ModrinthLoader`.
    static func fetchLoaderProfile(
        loaderId: String,
        loaderVersion: String,
        namespace: String,
        gameVersion: String,
    ) async throws -> ModrinthLoader {
        if let cachedData: Data = DIContainer.shared.core.appCacheManager.get(
            namespace: namespace,
            key: "profile",
            as: Data.self,
            directory: AppPaths.loaderCache,
        ) {
            return try decodeLoaderProfile(from: cachedData, loaderVersion: loaderVersion, gameVersion: gameVersion)
        }

        let url = URLConfig.API.Modrinth.loaderProfile(loader: loaderId, version: loaderVersion)
        let data = try await APIClient.get(url: url)
        let loader = try decodeLoaderProfile(from: data, loaderVersion: loaderVersion, gameVersion: gameVersion)

        do {
            try DIContainer.shared.core.appCacheManager.set(
                namespace: namespace,
                key: "profile",
                value: data,
                directory: AppPaths.loaderCache,
            )
        } catch {
            DIContainer.shared.core.errorHandler.handle(error)
        }

        return loader
    }

    /// Decodes a `ModrinthLoader` from raw JSON and applies game-version processing.
    private static func decodeLoaderProfile(
        from data: Data,
        loaderVersion: String,
        gameVersion: String,
    ) throws -> ModrinthLoader {
        var loader = try JSONDecoder().decode(ModrinthLoader.self, from: data)
        loader = processGameVersionPlaceholders(loader: loader, gameVersion: gameVersion)
        loader.version = loaderVersion
        return loader
    }

    /// Fetches loader version identifiers for the given loader type at the given Minecraft version.
    ///
    /// This is the shared implementation used by both game creation and loader version change
    /// flows. Returns an empty array for vanilla or unknown loaders.
    /// - Parameters:
    ///   - loader: The mod loader display name (e.g. "fabric", "forge").
    ///   - gameVersion: The Minecraft version string.
    /// - Returns: An array of loader version identifier strings.
    static func fetchLoaderVersionStrings(for loader: String, gameVersion: String) async -> [String] {
        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            return (try? await FabricLoaderService.fetchAllLoaderVersionsThrowing(for: gameVersion))?.map(\.loader.version) ?? []
        case GameLoader.forge.displayName:
            do {
                return try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion).loaders.map(\.id)
            } catch {
                AppLog.game.error("Failed to get Forge versions: \(error.localizedDescription)")
                return []
            }
        case GameLoader.neoforge.displayName:
            do {
                return try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion).loaders.map(\.id)
            } catch {
                AppLog.game.error("Failed to get NeoForge versions: \(error.localizedDescription)")
                return []
            }
        case GameLoader.quilt.rawValue:
            return (try? await QuiltLoaderService.fetchAllQuiltLoadersThrowing(for: gameVersion))?.map(\.loader.version) ?? []
        default:
            return []
        }
    }
}
