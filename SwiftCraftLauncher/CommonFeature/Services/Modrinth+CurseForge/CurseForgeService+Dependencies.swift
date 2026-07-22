//
//  CurseForgeService+Dependencies.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides dependency resolution for CurseForge projects.
extension CurseForgeService {
    /// Fetches project dependencies mapped to Modrinth format.
    static func fetchProjectDependenciesAsModrinth(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
    ) async -> ModrinthProjectDependency {
        await withServiceErrorHandling(context: "fetch CurseForge project dependencies (ID: \(id))", fallback: ModrinthProjectDependency(projects: [])) {
            try await fetchProjectDependenciesThrowingAsModrinth(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
            )
        }
    }

    /// Fetches project dependencies mapped to Modrinth format, throwing on failure.
    static func fetchProjectDependenciesThrowingAsModrinth(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
    ) async throws -> ModrinthProjectDependency {
        let versions = try await fetchProjectVersionsFilterAsModrinth(
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            type: type,
        )

        guard let firstVersion = versions.first else {
            return ModrinthProjectDependency(projects: [])
        }

        let requiredDeps = firstVersion.dependencies.filter { $0.dependencyType == "required" && $0.projectId != nil }
        let maxConcurrentTasks = 20
        var allDependencyVersions: [ModrinthProjectDetailVersion] = []

        var currentIndex = 0
        while currentIndex < requiredDeps.count {
            let endIndex = min(currentIndex + maxConcurrentTasks, requiredDeps.count)
            let batch = Array(requiredDeps[currentIndex ..< endIndex])
            currentIndex = endIndex

            let batchResults: [ModrinthProjectDetailVersion] = await withTaskGroup(of: ModrinthProjectDetailVersion?.self) { group in
                for dep in batch {
                    guard let projectId = dep.projectId else { continue }
                    group.addTask {
                        do {
                            let depVersion: ModrinthProjectDetailVersion

                            let normalizedProjectId = projectId.asProjectId.normalized

                            if let versionId = dep.versionId {
                                let versionIdentifier = versionId.asProjectId
                                if versionIdentifier.isCurseForge {
                                    let fileId = Int(versionId.replacingOccurrences(of: "cf-", with: "")) ?? 0
                                    let (modId, _) = try normalizedProjectId.asProjectId.parseCurseForgeId()
                                    let cfFile = try await fetchFileDetailThrowing(projectId: modId, fileId: fileId)
                                    guard let convertedVersion = CFToModrinthAdapter.convertFile(cfFile, projectId: normalizedProjectId) else {
                                        return nil
                                    }
                                    depVersion = convertedVersion
                                } else {
                                    depVersion = try await ModrinthService.fetchProjectVersionThrowing(id: versionId)
                                }
                            } else {
                                let depIdentifier = normalizedProjectId.asProjectId
                                if depIdentifier.isCurseForge {
                                    let depVersions = try await fetchProjectVersionsFilterAsModrinth(
                                        id: normalizedProjectId,
                                        selectedVersions: selectedVersions,
                                        selectedLoaders: selectedLoaders,
                                        type: type,
                                    )
                                    guard let firstDepVersion = depVersions.first else {
                                        return nil
                                    }
                                    depVersion = firstDepVersion
                                } else {
                                    let depVersions = try await ModrinthService.fetchProjectVersionsFilter(
                                        id: normalizedProjectId,
                                        selectedVersions: selectedVersions,
                                        selectedLoaders: selectedLoaders,
                                        type: type,
                                    )
                                    guard let firstDepVersion = depVersions.first else {
                                        return nil
                                    }
                                    depVersion = firstDepVersion
                                }
                            }

                            return depVersion
                        } catch {
                            let globalError = GlobalError.from(error)
                            AppLog.common.error("Failed to fetch dependency project version (ID: \(projectId)): \(globalError.localizedDescription)")
                            return nil
                        }
                    }
                }

                var results: [ModrinthProjectDetailVersion] = []
                for await result in group {
                    if let version = result {
                        results.append(version)
                    }
                }

                return results
            }

            allDependencyVersions.append(contentsOf: batchResults)
        }

        var missingDependencyVersions: [ModrinthProjectDetailVersion] = []

        for version in allDependencyVersions {
            let isInstalled = await ModrinthService.isProjectInstalledByAnyCompatibleVersion(
                projectId: version.projectId,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
                modsDir: cachePath,
            )

            if !isInstalled {
                missingDependencyVersions.append(version)
            }
        }

        return ModrinthProjectDependency(projects: missingDependencyVersions)
    }
}
