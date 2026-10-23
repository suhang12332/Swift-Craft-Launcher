//
//  ModrinthDependencyDownloader.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CFModrinthAdapterKit
import Foundation
import os

/// Downloads Modrinth project dependencies and manages recursive and manual dependency resolution.
enum ModrinthDependencyDownloader {
    /// Fetches missing dependencies with their available versions.
    static func getMissingDependenciesWithVersions(
        for projectId: String,
        gameInfo: GameVersionInfo,
    ) async -> [(
        detail: ModrinthProjectDetail, versions: [ModrinthProjectDetailVersion]
    )] {
        let query = ResourceType.mod.rawValue
        let resourceDir = AppPaths.modsDirectory(
            gameName: gameInfo.gameName,
        )

        let dependencies = (try? await ModrinthService.fetchProjectDependencies(
            type: query,
            cachePath: resourceDir,
            id: projectId,
            selectedVersions: [gameInfo.gameVersion],
            selectedLoaders: [gameInfo.modLoader],
        )) ?? ModrinthProjectDependency(projects: [])

        // Concurrently fetch project details and version info for all dependencies.
        return await withTaskGroup(
            of: (ModrinthProjectDetail, [ModrinthProjectDetailVersion])?.self,
        ) { group in
            for depVersion in dependencies.projects {
                group.addTask {
                    // Fetch the project detail.
                    guard
                        let projectDetail =
                        try? await ModrinthService.fetchProjectDetailsThrowing(
                            id: depVersion.projectId,
                        )
                    else {
                        return nil
                    }

                    let filteredVersions: [ModrinthProjectDetailVersion]
                    do {
                        filteredVersions = try await ModrinthService.fetchProjectVersionsFilter(
                            id: depVersion.projectId,
                            selectedVersions: [gameInfo.gameVersion],
                            selectedLoaders: [gameInfo.modLoader],
                            type: ResourceType.mod.rawValue,
                        )
                    } catch {
                        AppLog.resource.error("Failed to get versions for dependency \(projectDetail.title): \(error.localizedDescription)")
                        filteredVersions = []
                    }

                    return (projectDetail, filteredVersions)
                }
            }

            var results:
                [(
                    detail: ModrinthProjectDetail,
                    versions: [ModrinthProjectDetailVersion]
                )] = []
            for await result in group {
                if let (detail, versions) = result {
                    results.append((detail, versions))
                }
            }

            return results
        }
    }

    struct ManualDownloadInput {
        let dependencies: [ModrinthProjectDetail]
        let selectedVersions: [String: String]
        let dependencyVersions: [String: [ModrinthProjectDetailVersion]]
        let mainProjectId: String
        let mainProjectVersionId: String?
        let gameInfo: GameVersionInfo
        let resourceType: String
    }

    /// Downloads dependencies and the main mod manually, without recursion.
    static func downloadManualDependenciesAndMain(
        input: ManualDownloadInput,
        onDependencyDownloadStart: @escaping @Sendable (String) -> Void,
        onDependencyDownloadFinish: @escaping @Sendable (String, Bool) -> Void,
    ) async -> Bool {
        var resourcesToAdd: [ModrinthProjectDetail] = []
        var allSuccess = true
        let semaphore = AsyncSemaphore(
            value: DIContainer.shared.ui.gameSettingsManager.concurrentDownloads,
        )

        await withTaskGroup(of: (String, Bool, ModrinthProjectDetail?).self) { group in
            for dep in input.dependencies {
                guard let versionId = input.selectedVersions[dep.id],
                      let versions = input.dependencyVersions[dep.id],
                      let version = versions.first(where: { $0.id == versionId })
                else {
                    allSuccess = false
                    Task { @MainActor in
                        onDependencyDownloadFinish(dep.id, false)
                    }
                    continue
                }

                group.addTask {
                    var depCopy = dep
                    let depId = depCopy.id
                    await MainActor.run { onDependencyDownloadStart(depId) }
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    var success = false
                    do {
                        if let installed = try await ResourceInstaller.install(
                            version: version,
                            projectDetail: dep,
                            gameInfo: input.gameInfo,
                            resourceType: input.resourceType,
                        ) {
                            depCopy.fileName = installed.fileName
                            depCopy.type = input.resourceType
                            success = true
                        }
                    } catch {
                        let globalError = GlobalError.from(error)
                        AppLog.resource.error(
                            "Failed to download dependency \(depId): \(globalError.localizedDescription)",
                        )
                        success = false
                    }
                    let depCopyFinal = depCopy
                    return (depId, success, success ? depCopyFinal : nil)
                }
            }

            for await (depId, success, depCopy) in group {
                await MainActor.run {
                    onDependencyDownloadFinish(depId, success)
                }
                if success, let depCopy {
                    resourcesToAdd.append(depCopy)
                } else {
                    allSuccess = false
                }
            }
        }

        guard allSuccess else {
            return false
        }

        do {
            guard
                let mainProjectDetail =
                try? await ModrinthService.fetchProjectDetailsThrowing(id: input.mainProjectId)
            else {
                AppLog.resource.error("Unable to get main project details (ID: \(input.mainProjectId))")
                return false
            }

            let selectedLoaders = [input.gameInfo.modLoader]
            let filteredVersions =
                try await ModrinthService.fetchProjectVersionsFilter(
                    id: input.mainProjectId,
                    selectedVersions: [input.gameInfo.gameVersion],
                    selectedLoaders: selectedLoaders,
                    type: input.resourceType,
                )

            // Use the specified version or fall back to the latest.
            let targetVersion: ModrinthProjectDetailVersion
            if let mainProjectVersionId = input.mainProjectVersionId,
               let specifiedVersion = filteredVersions.first(where: {
                   $0.id == mainProjectVersionId
               }) {
                targetVersion = specifiedVersion
            } else if let latestVersion = filteredVersions.first {
                targetVersion = latestVersion
            } else {
                AppLog.resource.error("Unable to find a suitable version")
                return false
            }

            let installed = try await ResourceInstaller.install(
                version: targetVersion,
                projectDetail: mainProjectDetail,
                gameInfo: input.gameInfo,
                resourceType: input.resourceType,
            )
            guard installed != nil else {
                AppLog.resource.error("Unable to find main file")
                return false
            }
            return true
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.resource.error(
                "Failed to download main resource \(input.mainProjectId): \(globalError.localizedDescription)",
            )
            return false
        }
    }

    /// Downloads only the main resource without its dependencies.
    /// - Returns: A tuple of (success, fileName, hash). fileName and hash are non-nil on success.
    static func downloadMainResourceOnly(
        mainProjectId: String,
        gameInfo: GameVersionInfo,
        query: String,
        filterLoader: Bool = true,
    ) async -> (Bool, fileName: String?, hash: String?) {
        do {
            guard
                let mainProjectDetail =
                try? await ModrinthService.fetchProjectDetailsThrowing(id: mainProjectId)
            else {
                AppLog.resource.error("Unable to get main project details (ID: \(mainProjectId))")
                return (false, nil, nil)
            }
            let selectedLoaders = filterLoader ? [gameInfo.modLoader] : []
            let filteredVersions =
                try await ModrinthService.fetchProjectVersionsFilter(
                    id: mainProjectId,
                    selectedVersions: [gameInfo.gameVersion],
                    selectedLoaders: selectedLoaders,
                    type: query,
                )
            guard let latestVersion = filteredVersions.first else {
                return (false, nil, nil)
            }
            guard let installed = try await ResourceInstaller.install(
                version: latestVersion,
                projectDetail: mainProjectDetail,
                gameInfo: gameInfo,
                resourceType: query,
            ) else {
                return (false, nil, nil)
            }
            return (true, installed.fileName, installed.hash)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.resource.error(
                "Failed to download only main resource \(mainProjectId): \(globalError.localizedDescription)",
            )
            return (false, nil, nil)
        }
    }
}
