//
//  MinecraftLaunchCommandBuilder.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Builds the JVM launch command array for a Minecraft game session.
enum MinecraftLaunchCommandBuilder {
    static func build(
        manifest: MinecraftVersionManifest,
        gameInfo: GameVersionInfo,
        launcherBrand: String,
        launcherVersion: String,
    ) -> [String] {
        do {
            return try buildThrowing(
                manifest: manifest,
                gameInfo: gameInfo,
                launcherBrand: launcherBrand,
                launcherVersion: launcherVersion,
            )
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to build launch command: \(globalError.localizedDescription)")
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    static func buildThrowing(
        manifest: MinecraftVersionManifest,
        gameInfo: GameVersionInfo,
        launcherBrand _: String,
        launcherVersion: String,
    ) throws -> [String] {
        let paths = try validateAndGetPaths(gameInfo: gameInfo, manifest: manifest)

        let classpath = buildClasspath(
            manifest.libraries,
            librariesDir: paths.librariesDir,
            clientJarPath: paths.clientJarPath,
            modClassPath: gameInfo.modClassPath,
            minecraftVersion: manifest.id,
        )

        let variableMap: [String: String] = [
            "auth_player_name": "${auth_player_name}",
            "version_name": gameInfo.gameVersion,
            "game_directory": paths.gameDir,
            "assets_root": paths.assetsDir,
            "assets_index_name": gameInfo.assetIndex,
            "auth_uuid": "${auth_uuid}",
            "auth_access_token": "${auth_access_token}",
            "clientid": AppConstants.minecraftClientId,
            "auth_xuid": "${auth_xuid}",
            "user_type": "msa",
            "version_type": Bundle.main.appName,
            "natives_directory": paths.nativesDir,
            "launcher_name": Bundle.main.appName,
            "launcher_version": launcherVersion,
            "classpath": classpath,
        ]

        var jvmArgs = manifest.arguments.jvm?
            .map { substituteVariables($0, with: variableMap) } ?? []
        var gameArgs = manifest.arguments.game?
            .map { substituteVariables($0, with: variableMap) } ?? []

        let xmsArg = "-Xms${xms}M"
        let xmxArg = "-Xmx${xmx}M"
        jvmArgs.insert(contentsOf: [xmsArg, xmxArg], at: 0)

        jvmArgs.insert("-XstartOnFirstThread", at: 0)

        if !gameInfo.modJvm.isEmpty {
            jvmArgs.append(contentsOf: gameInfo.modJvm)
        }

        if !gameInfo.gameArguments.isEmpty {
            gameArgs.append(contentsOf: gameInfo.gameArguments)
        }

        return jvmArgs + [gameInfo.mainClass] + gameArgs
    }

    private struct GamePaths {
        let nativesDir: String
        let librariesDir: URL
        let assetsDir: String
        let gameDir: String
        let clientJarPath: String
    }

    private static func validateAndGetPaths(
        gameInfo: GameVersionInfo,
        manifest: MinecraftVersionManifest,
    ) throws -> GamePaths {
        let clientJarPath = AppPaths.versionsDirectory.appendingPathComponent(manifest.id).appendingPathComponent("\(manifest.id).jar").path
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: clientJarPath) else {
            throw GlobalError.resource(
                i18nKey: "error.resource.client_jar_not_found",
                level: .popup,
            )
        }

        return GamePaths(
            nativesDir: AppPaths.nativesDirectory.path,
            librariesDir: AppPaths.librariesDirectory,
            assetsDir: AppPaths.assetsDirectory.path,
            gameDir: AppPaths.profileDirectory(gameName: gameInfo.gameName).path,
            clientJarPath: clientJarPath,
        )
    }

    private static func substituteVariables(_ arg: String, with map: [String: String]) -> String {
        guard arg.contains("${") else {
            return arg
        }

        let result = NSMutableString(string: arg)
        for (key, value) in map {
            let placeholder = "${\(key)}"
            if result.range(of: placeholder).location != NSNotFound {
                result.replaceOccurrences(
                    of: placeholder,
                    with: value,
                    options: [],
                    range: NSRange(location: 0, length: result.length),
                )
            }
        }
        return result as String
    }

    private static func buildClasspath(_ libraries: [Library], librariesDir: URL, clientJarPath: String, modClassPath: String, minecraftVersion: String) -> String {
        AppLog.game.debug("Starting classpath build - library count: \(libraries.count), mod classpath: \(modClassPath.isEmpty ? "none" : "\(modClassPath.split(separator: ":").count) paths")")

        let modClassPaths = parseModClassPath(modClassPath, librariesDir: librariesDir)
        let existingModBasePaths = extractBasePaths(from: modClassPaths, librariesDir: librariesDir)
        AppLog.game.debug("Parsed \(modClassPaths.count) mod classpaths, \(existingModBasePaths.count) base paths")

        let manifestLibraryPaths = libraries
            .filter { shouldIncludeLibrary($0, minecraftVersion: minecraftVersion) }
            .compactMap { library in
                processLibrary(library, librariesDir: librariesDir, existingModBasePaths: existingModBasePaths, minecraftVersion: minecraftVersion)
            }
            .flatMap(\.self)

        AppLog.game.debug("Processing complete - manifest library paths: \(manifestLibraryPaths.count) items")

        let allPaths = manifestLibraryPaths + [clientJarPath] + modClassPaths
        let uniquePaths = removeDuplicatePaths(allPaths)
        let classpath = uniquePaths.joined(separator: ":")

        AppLog.game.debug("Classpath build complete - raw path count: \(allPaths.count), after dedup: \(uniquePaths.count)")
        return classpath
    }

    private static func parseModClassPath(_ modClassPath: String, librariesDir _: URL) -> [String] {
        modClassPath.split(separator: ":").map { String($0) }
    }

    private static func removeDuplicatePaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { path in
            let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedPath.isEmpty else { return false }

            if seen.contains(normalizedPath) {
                AppLog.game.debug("Found duplicate path, skipped: \(normalizedPath)")
                return false
            } else {
                seen.insert(normalizedPath)
                return true
            }
        }
    }

    private static func extractBasePaths(from paths: [String], librariesDir: URL) -> Set<String> {
        let librariesDirPath = librariesDir.path.appending("/")

        return Set(paths.compactMap { path in
            guard path.hasPrefix(librariesDirPath) else { return nil }
            let relPath = String(path.dropFirst(librariesDirPath.count))
            return extractBasePath(from: relPath)
        })
    }

    private static func extractBasePath(from relativePath: String) -> String? {
        let pathComponents = relativePath.split(separator: "/")
        guard pathComponents.count >= 2 else { return nil }
        return pathComponents.dropLast(2).joined(separator: "/")
    }

    private static func processLibrary(_ library: Library, librariesDir: URL, existingModBasePaths: Set<String>, minecraftVersion _: String) -> [String]? {
        let artifact = library.downloads.artifact

        let libraryPath = getLibraryPath(artifact: artifact, libraryName: library.name, librariesDir: librariesDir)

        let relativePath = String(libraryPath.dropFirst(librariesDir.path.appending("/").count))
        guard let basePath = extractBasePath(from: relativePath) else { return nil }

        if existingModBasePaths.contains(basePath) {
            return nil
        }
        return [libraryPath]
    }

    private static func getLibraryPath(artifact: LibraryArtifact, libraryName: String, librariesDir: URL) -> String {
        if let existingPath = artifact.path {
            return librariesDir.appendingPathComponent(existingPath).path
        } else {
            let fullPath = CommonService.convertMavenCoordinateToPath(libraryName)
            AppLog.game.debug("Library file \(libraryName) missing path info, generated path from Maven coordinate: \(fullPath)")
            return fullPath
        }
    }

    private static func getClassifierPaths(library _: Library, librariesDir _: URL, minecraftVersion _: String) -> [String] {
        []
    }

    private static func shouldIncludeLibrary(_ library: Library, minecraftVersion: String? = nil) -> Bool {
        guard library.downloadable == true, library.includeInClasspath == true else {
            return false
        }

        return LibraryFilter.isLibraryAllowed(library, minecraftVersion: minecraftVersion)
    }
}
