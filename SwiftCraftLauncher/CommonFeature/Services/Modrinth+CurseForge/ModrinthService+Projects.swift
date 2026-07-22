//
//  ModrinthService+Projects.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides project detail and version retrieval for Modrinth and CurseForge projects.
extension ModrinthService {
    static func fetchProjectDetails(id: String, type: String = "") async -> ModrinthProjectDetail? {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return await CurseForgeService.fetchProjectDetailsAsModrinth(id: id)
        }

        if !type.isEmpty {
            guard let result = await fetchProjectDetailsV3(id: id) else { return nil }
            return ModrinthProjectDetail.fromV3(result)
        }
        return await withServiceErrorHandling(context: "fetch project details (ID: \(id))", fallback: nil) {
            try await fetchProjectDetailsThrowing(id: id)
        }
    }

    static func fetchProjectDetailsThrowing(id: String) async throws -> ModrinthProjectDetail {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return try await CurseForgeService.fetchProjectDetailsAsModrinthThrowing(id: id)
        }

        let url = URLConfig.API.Modrinth.project(id: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        var detail = try decoder.decode(ModrinthProjectDetail.self, from: data)

        let releaseGameVersions = detail.gameVersions.filter {
            $0.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
        }
        let result = CommonUtil.sortMinecraftVersions(releaseGameVersions)
        detail.gameVersions = CommonUtil.versionsAtLeast(result)

        return detail
    }

    static func fetchProjectDetailsV3(id: String) async -> ModrinthProjectDetailV3? {
        await withServiceErrorHandling(context: "fetch v3 project details (ID: \(id))", fallback: nil) {
            try await fetchProjectDetailsV3Throwing(id: id)
        }
    }

    static func fetchProjectDetailsV3Throwing(id: String) async throws -> ModrinthProjectDetailV3 {
        let url = URLConfig.API.Modrinth.projectV3(id: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailV3.self, from: data)
    }

    static func fetchProjectVersions(id: String) async -> [ModrinthProjectDetailVersion] {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return await CurseForgeService.fetchProjectVersionsAsModrinth(id: id)
        }

        return await withServiceErrorHandling(context: "fetch project version list (ID: \(id))", fallback: []) {
            try await fetchProjectVersionsThrowing(id: id)
        }
    }

    static func fetchProjectVersionsThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return try await CurseForgeService.fetchProjectVersionsAsModrinthThrowing(id: id)
        }

        let url = URLConfig.API.Modrinth.version(id: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode([ModrinthProjectDetailVersion].self, from: data)
    }

    static func fetchProjectVersionsFilter(
        id: String,
        selectedVersions: [String],
        selectedLoaders: [String],
        type: String,
    ) async throws -> [ModrinthProjectDetailVersion] {
        let projectId = id.asProjectId

        if projectId.isCurseForge {
            return try await CurseForgeService.fetchProjectVersionsFilterAsModrinth(
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
            )
        }

        let versions = try await fetchProjectVersionsThrowing(id: id)
        return VersionFilter.filter(
            versions,
            selectedVersions: selectedVersions,
            selectedLoaders: selectedLoaders,
            type: type,
        )
    }

    static func fetchProjectVersionThrowing(id: String) async throws -> ModrinthProjectDetailVersion {
        let url = URLConfig.API.Modrinth.versionId(versionId: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailVersion.self, from: data)
    }
}
