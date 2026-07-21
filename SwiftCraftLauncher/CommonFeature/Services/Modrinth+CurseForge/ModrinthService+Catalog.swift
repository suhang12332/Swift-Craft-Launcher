//
//  ModrinthService+Catalog.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides catalog operations for Modrinth loaders, categories, and game versions.
extension ModrinthService {
    static func fetchLoaders() async -> [Loader] {
        await withServiceErrorHandling(context: "fetch Modrinth loader list", fallback: []) {
            try await fetchLoadersThrowing()
        }
    }

    static func fetchLoadersThrowing() async throws -> [Loader] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.loaderTag)
        return try JSONDecoder().decode([Loader].self, from: data)
    }

    static func fetchCategories() async -> [Category] {
        await withServiceErrorHandling(context: "fetch Modrinth category list", fallback: []) {
            try await fetchCategoriesThrowing()
        }
    }

    static func fetchCategoriesThrowing() async throws -> [Category] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.categoryTag)
        return try JSONDecoder().decode([Category].self, from: data)
    }

    static func fetchGameVersions(includeSnapshots: Bool = false) async -> [GameVersion] {
        await withServiceErrorHandling(context: "fetch Modrinth game version list", fallback: []) {
            try await fetchGameVersionsThrowing(includeSnapshots: includeSnapshots)
        }
    }

    static func fetchGameVersionsThrowing(
        includeSnapshots: Bool = false,
    ) async throws -> [GameVersion] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.gameVersionTag)
        let result = try JSONDecoder().decode([GameVersion].self, from: data)
        return includeSnapshots ? result : result.filter { $0.version_type == "release" }
    }
}
