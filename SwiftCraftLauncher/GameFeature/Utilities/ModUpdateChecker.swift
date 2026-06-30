//
//  ModUpdateChecker.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Checks whether locally installed mods have updates available on Modrinth.
enum ModUpdateChecker {
    /// The result of an update check.
    struct UpdateCheckResult {
        /// Whether a newer version is available.
        let hasUpdate: Bool
        /// The SHA-1 hash of the currently installed file.
        let currentHash: String?
        /// The SHA-1 hash of the latest available file.
        let latestHash: String?
        /// The latest available version metadata.
        let latestVersion: ModrinthProjectDetailVersion?
    }

    /// Checks whether a locally installed mod has an update available.
    /// - Parameters:
    ///   - projectId: The Modrinth project identifier.
    ///   - gameInfo: The game version and loader information.
    ///   - resourceType: The resource type (mod, datapack, shader, resourcepack).
    ///   - installedFileName: The file name of the currently installed resource, maintained by the caller.
    /// - Returns: The update check result.
    static func checkForUpdate(
        projectId: String,
        gameInfo: GameVersionInfo,
        resourceType: String,
        installedFileName: String? = nil,
    ) async -> UpdateCheckResult {
        guard let resourceDir = AppPaths.resourceDirectory(
            for: resourceType,
            gameName: gameInfo.gameName,
        ) else {
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: nil,
                latestHash: nil,
                latestVersion: nil,
            )
        }

        let currentHash = await getCurrentInstalledHash(
            resourceDir: resourceDir,
            installedFileName: installedFileName,
        )

        guard let currentHash else {
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: nil,
                latestHash: nil,
                latestVersion: nil,
            )
        }

        let loaderFilters = [gameInfo.modLoader.lowercased()]
        let versionFilters = [gameInfo.gameVersion]

        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType,
            )

            guard let latestVersion = versions.first,
                  let primaryFile = ModrinthService.filterPrimaryFiles(
                      from: latestVersion.files,
                  ) else {
                return UpdateCheckResult(
                    hasUpdate: false,
                    currentHash: currentHash,
                    latestHash: nil,
                    latestVersion: nil,
                )
            }

            let latestHash = primaryFile.hashes.sha1

            let hasUpdate = currentHash != latestHash

            return UpdateCheckResult(
                hasUpdate: hasUpdate,
                currentHash: currentHash,
                latestHash: latestHash,
                latestVersion: latestVersion,
            )
        } catch {
            Logger.shared.error("检测 mod 更新失败: \(error.localizedDescription)")
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: currentHash,
                latestHash: nil,
                latestVersion: nil,
            )
        }
    }

    /// Returns the SHA-1 hash of the currently installed file.
    /// - Parameters:
    ///   - resourceDir: The directory containing the installed resource.
    ///   - installedFileName: The file name of the installed resource.
    /// - Returns: The SHA-1 hash, or `nil` if the file does not exist.
    private static func getCurrentInstalledHash(
        resourceDir: URL,
        installedFileName: String?,
    ) async -> String? {
        if let fileName = installedFileName {
            let fileURL = resourceDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return AppServices.modScanner.sha1Hash(of: fileURL)
            }
        }
        return nil
    }
}
