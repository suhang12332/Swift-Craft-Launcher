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
        let context = DependencyResolver.Context(
            type: type,
            cachePath: cachePath,
            id: id,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            fetchVersions: { projectID in
                try await fetchProjectVersions(
                    id: projectID,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoaders,
                    type: type,
                )
            },
            // CurseForge dependencies carry no fileId (API limitation), so version-level
            // lookup is not needed; resolution falls back to the first compatible version.
            fetchVersionById: nil,
        )
        return await DependencyResolver.resolve(context)
    }

    /// Fetches versions for a project, handling both CurseForge and Modrinth IDs.
    private static func fetchProjectVersions(
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
    ) async throws -> [ModrinthProjectDetailVersion] {
        let projectIdentifier = id.asProjectId
        if projectIdentifier.isCurseForge {
            return try await fetchProjectVersionsFilterAsModrinth(
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
            )
        } else {
            return try await ModrinthService.fetchProjectVersionsFilter(
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
            )
        }
    }
}
