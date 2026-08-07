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
            fetchVersionById: { versionID in
                try await fetchVersionById(versionID)
            },
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

    /// Fetches a version by ID, handling both CurseForge and Modrinth IDs.
    private static func fetchVersionById(_ versionID: String) async throws -> ModrinthProjectDetailVersion {
        let versionIdentifier = versionID.asProjectId
        if versionIdentifier.isCurseForge {
            let fileId = Int(versionID.replacingOccurrences(of: "cf-", with: "")) ?? 0
            let normalizedProjectId = versionID.asProjectId.normalized
            let (modId, _) = try normalizedProjectId.asProjectId.parseCurseForgeId()
            let cfFile = try await fetchFileDetailThrowing(projectId: modId, fileId: fileId)
            guard let convertedVersion = CFToModrinthAdapter.convertFile(cfFile, projectId: normalizedProjectId) else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.version_convert_failed",
                    level: .notification,
                    message: "Failed to convert CurseForge file to Modrinth format for versionId=\(versionID)",
                )
            }
            return convertedVersion
        } else {
            return try await ModrinthService.fetchProjectVersionThrowing(id: versionID)
        }
    }
}
