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
        do {
            return try await fetchProjectDependenciesThrowing(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取项目依赖失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return ModrinthProjectDependency(projects: [])
        }
    }

    static func fetchProjectDependenciesThrowing(
        type: String,
        cachePath: URL,
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
    ) async throws -> ModrinthProjectDependency {
        if id.hasPrefix("cf-") {
            return try await CurseForgeService.fetchProjectDependenciesThrowingAsModrinth(
                type: type,
                cachePath: cachePath,
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
            )
        }

        let versions = try await fetchProjectVersionsFilter(
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            type: type,
        )
        guard let firstVersion = versions.first else {
            return ModrinthProjectDependency(projects: [])
        }

        let requiredDeps = firstVersion.dependencies.filter {
            $0.dependencyType == "required" && $0.projectId != nil
        }
        let maxConcurrentTasks = 10
        var allDependencyVersions: [ModrinthProjectDetailVersion] = []

        var currentIndex = 0
        while currentIndex < requiredDeps.count {
            let endIndex = min(currentIndex + maxConcurrentTasks, requiredDeps.count)
            let batch = Array(requiredDeps[currentIndex ..< endIndex])
            currentIndex = endIndex

            let batchResults: [ModrinthProjectDetailVersion] = await withTaskGroup(
                of: ModrinthProjectDetailVersion?.self,
            ) { group in
                for dep in batch {
                    guard let projectId = dep.projectId else { continue }
                    group.addTask {
                        do {
                            let depVersion: ModrinthProjectDetailVersion

                            if let versionId = dep.versionId {
                                depVersion = try await fetchProjectVersionThrowing(id: versionId)
                            } else {
                                let depVersions = try await fetchProjectVersionsFilter(
                                    id: projectId,
                                    selectedVersions: selectedVersions,
                                    selectedLoaders: selectedLoaders,
                                    type: type,
                                )
                                guard let firstDepVersion = depVersions.first else {
                                    Logger.shared.warning("未找到兼容的依赖版本 (ID: \(projectId))")
                                    return nil
                                }
                                depVersion = firstDepVersion
                            }

                            return depVersion
                        } catch {
                            let globalError = GlobalError.from(error)
                            Logger.shared.error(
                                "获取依赖项目版本失败 (ID: \(projectId)): \(globalError.chineseMessage)",
                            )
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
            let isInstalled = await isProjectInstalledByAnyCompatibleVersion(
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

    static func isProjectInstalledByAnyCompatibleVersion(
        projectId: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
        modsDir: URL,
    ) async -> Bool {
        do {
            let versions: [ModrinthProjectDetailVersion]

            if projectId.hasPrefix("cf-") {
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
                    if (try? await AppServices.modScanner.isModInstalledThrowing(hash: hash, in: modsDir)) == true {
                        return true
                    }
                } else {
                    let isInstalled = await AppServices.modScanner.isResourceInstalledByHash(
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
            Logger.shared.error("检查项目安装状态失败 (ID: \(projectId)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
        }

        return false
    }
}
