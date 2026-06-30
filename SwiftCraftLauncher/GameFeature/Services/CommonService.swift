//
//  CommonService.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides shared utilities for mod loader version management and classpath generation.
enum CommonService {
    static func compatibleVersions(
        for loader: String,
        includeSnapshots: Bool = false,
    ) async -> [String] {
        do {
            return try await compatibleVersionsThrowing(
                for: loader,
                includeSnapshots: includeSnapshots,
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(
                "获取 \(loader) 版本失败: \(globalError.chineseMessage)",
            )
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

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
            let gameVersions = await ModrinthService.fetchGameVersions(
                includeSnapshots: includeSnapshots,
            )
            let versionNames = gameVersions
                .map { version in
                    let cacheKey = "version_time_\(version.version)"
                    let formattedTime = CommonUtil.formatRelativeTime(
                        version.date,
                    )
                    AppServices.appCacheManager.setSilently(
                        namespace: "version_time",
                        key: cacheKey,
                        value: formattedTime,
                    )
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

    static func fetchAllLoaderVersions(
        type: String,
        minecraftVersion: String,
    ) async -> LoaderVersion? {
        do {
            return try await fetchAllLoaderVersionsThrowing(
                type: type,
                minecraftVersion: minecraftVersion,
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取加载器版本失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return nil
        }
    }

    static func fetchAllLoaderVersionsThrowing(
        type: String,
        minecraftVersion: String,
    ) async throws -> LoaderVersion {
        let manifest = try await fetchAllVersionThrowing(type: type)

        let filteredVersions = manifest.filter { $0.id == minecraftVersion }

        guard let firstVersion = filteredVersions.first else {
            throw GlobalError.resource(
                chineseMessage:
                    "未找到 Minecraft \(minecraftVersion) 的 \(type) 加载器版本",
                i18nKey: "error.resource.loader_version_not_found",
                level: .notification,
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
                chineseMessage:
                    "解析 \(type) 版本清单失败: \(error.localizedDescription)",
                i18nKey: "error.validation.version_manifest_parse_failed",
                level: .notification,
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
            return convertMavenCoordinateWithAtSymbolForURL(coordinate)
        }

        if let relativePath = mavenCoordinateToRelativePath(coordinate) {
            return relativePath
        }

        return coordinate
    }

    static func convertMavenCoordinateWithAtSymbolForURL(
        _ coordinate: String,
    ) -> String {
        parseMavenCoordinateWithAtSymbol(coordinate)
    }

    static func mavenCoordinateToURL(lib: ModrinthLoaderLibrary) -> URL? {
        let relativePath = mavenCoordinateToRelativePathForURL(lib.name)
        return lib.url?.appendingPathComponent(relativePath)
    }

    static func mavenCoordinateToDefaultURL(_ coordinate: String, url: URL) -> URL {
        let relativePath = mavenCoordinateToRelativePathForURL(coordinate)
        return url.appendingPathComponent(relativePath)
    }

    static func mavenCoordinateToDefaultPath(_ coordinate: String) -> String {
        mavenCoordinateToRelativePathForURL(coordinate)
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
}
