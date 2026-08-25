//
//  ModrinthService+Catalog.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides catalog operations for Modrinth loaders, categories, and game versions.
extension ModrinthService {
    static func fetchLoadersThrowing() async throws -> [Loader] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.loaderTag)
        return try JSONDecoder().decode([Loader].self, from: data)
    }

    static func fetchCategoriesThrowing() async throws -> [Category] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.categoryTag)
        return try JSONDecoder().decode([Category].self, from: data)
    }

    static func fetchGameVersionsThrowing(
        includeSnapshots: Bool = false,
    ) async throws -> [GameVersion] {
        let data = try await APIClient.get(url: URLConfig.API.Modrinth.gameVersionTag)
        let result = try JSONDecoder().decode([GameVersion].self, from: data)
        return includeSnapshots ? result : result.filter { $0.version_type == "release" }
    }
}
