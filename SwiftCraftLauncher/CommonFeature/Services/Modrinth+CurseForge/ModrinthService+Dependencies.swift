//
//  ModrinthService+Dependencies.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides dependency resolution for Modrinth projects.
extension ModrinthService {
    static func fetchProjectDependencies(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
    ) async -> ModrinthProjectDependency {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return await CurseForgeService.fetchProjectDependenciesAsModrinth(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
            )
        }

        let context = DependencyResolver.Context(
            type: type,
            cachePath: cachePath,
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            fetchVersions: { projectID in
                try await fetchProjectVersionsFilter(
                    id: projectID,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type,
                )
            },
            fetchVersionById: { versionID in
                try await fetchProjectVersionThrowing(id: versionID)
            },
        )
        return await DependencyResolver.resolve(context)
    }

    static func isProjectInstalledByAnyCompatibleVersion(
        projectId: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
        modsDir: URL,
    ) async -> Bool {
        do {
            let projectIdentifier = projectId.asProjectId
            let versions: [ModrinthProjectDetailVersion]

            if projectIdentifier.isCurseForge {
                versions = try await CurseForgeService.fetchProjectVersionsFilterAsModrinth(
                    id: projectId,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type,
                )
            } else {
                versions = try await fetchProjectVersionsFilter(
                    id: projectId,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type,
                )
            }

            for version in versions {
                guard let primaryFile = filterPrimaryFiles(from: version.files) else {
                    continue
                }
                let hash = primaryFile.hashes.sha1
                let lowercasedType = type.lowercased()

                if lowercasedType == ResourceType.mod.rawValue {
                    if (try? await DIContainer.shared.core.modScanner.isModInstalled(hash: hash, in: modsDir)) == true {
                        return true
                    }
                } else {
                    let isInstalled = await DIContainer.shared.core.modScanner.isResourceInstalledByHash(
                        hash,
                        in: modsDir,
                    )
                    if isInstalled {
                        return true
                    }
                }
            }
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to check project installation status (ID: \(projectId)): \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }

        return false
    }
}
