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
        gameInfo: GameVersionInfo?,
    ) async -> Bool {
        if resourceType == ResourceType.minecraftJavaServer.rawValue {
            guard !installedHashes.isEmpty,
                  let address = await serverAddress(for: project)
            else { return false }
            return installedHashes.contains(CommonUtil.serverMatchKey(address: address))
        }

        guard !installedHashes.isEmpty else { return false }

        // Build version and loader filters using user selection or game info as fallback.
        let versionFilters: [String] = {
            if !selectedVersions.isEmpty {
                return selectedVersions
            }
            if let gameInfo {
                return [gameInfo.gameVersion]
            }
            return []
        }()

        let loaderFilters: [String] = {
            if !selectedLoaders.isEmpty {
                return selectedLoaders.map { $0.lowercased() }
            }
            if let gameInfo {
                return [gameInfo.modLoader.lowercased()]
            }
            return []
        }()

        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: project.projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType,
            )

            for version in versions {
                guard
                    let primaryFile = ModrinthService.filterPrimaryFiles(
                        from: version.files,
                    )
                else { continue }

                if installedHashes.contains(primaryFile.hashes.sha1) {
                    return true
                }
            }
        } catch {
            AppLog.resource.error(
                "Failed to get project versions for installation check: \(error.localizedDescription)",
            )
        }

        return false
    }

    /// Resolves the server address for a Minecraft Java server project.
    ///
    /// Uses the project's file name when available, otherwise fetches the project detail.
    private static func serverAddress(for project: ModrinthProject) async -> String? {
        if let fileName = project.fileName,
           !fileName.isEmpty {
            let address = CommonUtil.parseMinecraftJavaServerInfo(from: fileName).address
            if !address.isEmpty {
                return address
            }
        }

        guard let detail = await ModrinthService.fetchProjectDetails(
            id: project.projectId,
            type: ResourceType.minecraftJavaServer.rawValue,
        ) else { return nil }
        return MinecraftJavaServerResourceUtils.parseAddress(from: detail)
    }
}
