//
//  DependencyResolver.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Unified dependency resolution for both Modrinth and CurseForge projects.
///
/// The core algorithm (fetch first version → resolve required deps in batches →
/// filter already-installed) is shared. Provider-specific fetching is injected
/// via closures so the resolver stays decoupled from either API.
enum DependencyResolver {
    /// Bundles the parameters shared across the resolution pipeline.
    struct Context {
        let type: String
        let cachePath: URL
        let id: String
        let selectedVersions: [String]
        let selectedLoaders: [String]
        let fetchVersions: (String) async throws -> [ModrinthProjectDetailVersion]
        let fetchVersionById: (String) async throws -> ModrinthProjectDetailVersion
    }

    /// Resolves missing dependencies for a project.
    static func resolve(_ context: Context) async -> ModrinthProjectDependency {
        await withServiceErrorHandling(
            context: "resolve dependencies (ID: \(context.id))",
            fallback: ModrinthProjectDependency(projects: []),
        ) {
            try await resolveThrowing(context)
        }
    }

    static func resolveThrowing(_ context: Context) async throws -> ModrinthProjectDependency {
        let versions = try await context.fetchVersions(context.id)
        guard let firstVersion = versions.first else {
            return ModrinthProjectDependency(projects: [])
        }

        let requiredDeps = firstVersion.dependencies.filter {
            $0.dependencyType == "required" && $0.projectId != nil
        }

        let allDependencyVersions = try await resolveDependencyVersions(
            requiredDeps: requiredDeps,
            context: context,
        )

        let missingVersions = try await filterInstalled(
            dependencyVersions: allDependencyVersions,
            context: context,
        )

        return ModrinthProjectDependency(projects: missingVersions)
    }

    /// Resolves dependency versions in batches with bounded concurrency.
    private static func resolveDependencyVersions(
        requiredDeps: [ModrinthVersionDependency],
        context: Context,
    ) async throws -> [ModrinthProjectDetailVersion] {
        let maxConcurrentTasks = 10
        var allVersions: [ModrinthProjectDetailVersion] = []
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
                            if let versionId = dep.versionId {
                                return try await context.fetchVersionById(versionId)
                            } else {
                                let depVersions = try await context.fetchVersions(projectId)
                                guard let first = depVersions.first else {
                                    AppLog.common.error("No compatible dependency version found (ID: \(projectId))")
                                    return nil
                                }
                                return first
                            }
                        } catch {
                            let globalError = GlobalError.from(error)
                            AppLog.common.error(
                                "Failed to fetch dependency version (ID: \(projectId)): \(globalError.localizedDescription)",
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

            allVersions.append(contentsOf: batchResults)
        }

        return allVersions
    }

    /// Filters out dependency versions that are already installed.
    private static func filterInstalled(
        dependencyVersions: [ModrinthProjectDetailVersion],
        context: Context,
    ) async throws -> [ModrinthProjectDetailVersion] {
        var missing: [ModrinthProjectDetailVersion] = []

        for version in dependencyVersions {
            let isInstalled = await ModrinthService.isProjectInstalledByAnyCompatibleVersion(
                projectId: version.projectId,
                selectedVersions: context.selectedVersions,
                selectedLoaders: context.selectedLoaders,
                type: context.type,
                modsDir: context.cachePath,
            )
            if !isInstalled {
                missing.append(version)
            }
        }

        return missing
    }
}
