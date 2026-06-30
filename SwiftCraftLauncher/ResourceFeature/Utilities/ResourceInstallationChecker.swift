//
//  ResourceInstallationChecker.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Checks whether a resource is already installed for a given game.
enum ResourceInstallationChecker {
    /// Checks whether a resource is installed in server mode.
    ///
    /// Uses version and loader filters from user selection or falls back to the current game info.
    /// - Parameters:
    ///   - project: The Modrinth project to check.
    ///   - resourceType: The type of resource.
    ///   - installedHashes: The set of installed resource hashes.
    ///   - selectedVersions: The selected game versions.
    ///   - selectedLoaders: The selected mod loaders.
    ///   - gameInfo: Optional game info used as fallback.
    /// - Returns: Whether the resource is installed.
    static func checkInstalledStateForServerMode(
        project: ModrinthProject,
        resourceType: String,
        installedHashes: Set<String>,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?
    ) async -> Bool {
        guard !installedHashes.isEmpty else { return false }

        // Build version and loader filters using user selection or game info as fallback.
        let versionFilters: [String] = {
            if !selectedVersions.isEmpty {
                return selectedVersions
            }
            if let gameInfo = gameInfo {
                return [gameInfo.gameVersion]
            }
            return []
        }()

        let loaderFilters: [String] = {
            if !selectedLoaders.isEmpty {
                return selectedLoaders.map { $0.lowercased() }
            }
            if let gameInfo = gameInfo {
                return [gameInfo.modLoader.lowercased()]
            }
            return []
        }()

        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: project.projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType
            )

            for version in versions {
                guard
                    let primaryFile = ModrinthService.filterPrimaryFiles(
                        from: version.files
                    )
                else { continue }

                if installedHashes.contains(primaryFile.hashes.sha1) {
                    return true
                }
            }
        } catch {
            Logger.shared.error(
                "获取项目版本以检查安装状态失败: \(error.localizedDescription)"
            )
        }

        return false
    }
}
