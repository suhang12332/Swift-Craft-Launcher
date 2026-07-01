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
        if id.hasPrefix("cf-") {
            return await CurseForgeService.fetchProjectDetailsAsModrinth(id: id)
        }

        if !type.isEmpty {
            guard let result = await fetchProjectDetailsV3(id: id) else { return nil }
            return ModrinthProjectDetail.fromV3(result)
        }
        do {
            return try await fetchProjectDetailsThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("获取项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return nil
        }
    }

    static func fetchProjectDetailsThrowing(id: String) async throws -> ModrinthProjectDetail {
        if id.hasPrefix("cf-") {
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
        do {
            return try await fetchProjectDetailsV3Throwing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("获取 v3 项目详情失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return nil
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
        if id.hasPrefix("cf-") {
            return await CurseForgeService.fetchProjectVersionsAsModrinth(id: id)
        }

        do {
            return try await fetchProjectVersionsThrowing(id: id)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("获取项目版本列表失败 (ID: \(id)): \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return []
        }
    }

    static func fetchProjectVersionsThrowing(id: String) async throws -> [ModrinthProjectDetailVersion] {
        if id.hasPrefix("cf-") {
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
        if id.hasPrefix("cf-") {
            return try await CurseForgeService.fetchProjectVersionsFilterAsModrinth(
                id: id,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                type: type,
            )
        }

        let versions = try await fetchProjectVersionsThrowing(id: id)
        var loaders = selectedLoaders
        if type == ResourceType.datapack.rawValue {
            loaders = [ResourceType.datapack.rawValue]
        } else if type == ResourceType.resourcepack.rawValue {
            loaders = ["minecraft"]
        }
        return versions.filter { version in
            let versionMatch = selectedVersions.isEmpty
                || !Set(version.gameVersions).isDisjoint(with: selectedVersions)

            let loaderMatch: Bool
            if type == ResourceType.shader.rawValue || type == ResourceType.resourcepack.rawValue {
                loaderMatch = true
            } else {
                loaderMatch = loaders.isEmpty || !Set(version.loaders).isDisjoint(with: loaders)
            }

            return versionMatch && loaderMatch
        }
    }

    static func fetchProjectVersionThrowing(id: String) async throws -> ModrinthProjectDetailVersion {
        let url = URLConfig.API.Modrinth.versionId(versionId: id)
        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthProjectDetailVersion.self, from: data)
    }
}
