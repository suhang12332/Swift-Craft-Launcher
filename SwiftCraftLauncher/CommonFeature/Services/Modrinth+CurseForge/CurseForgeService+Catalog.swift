//
//  CurseForgeService+Catalog.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides catalog operations for CurseForge categories and game versions.
extension CurseForgeService {
    static func fetchCategories() async -> [CurseForgeCategory] {
        await withServiceErrorHandling(context: "fetch CurseForge category list", fallback: []) {
            try await fetchCategoriesThrowing()
        }
    }

    /// Fetches the list of CurseForge categories, throwing on failure.
    /// - Returns: An array of categories.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchCategoriesThrowing() async throws -> [CurseForgeCategory] {
        let headers = getHeaders()
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.categories, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeCategoriesResponse.self, from: data)
        return result.data
    }

    static func fetchGameVersions() async -> [CurseForgeGameVersion] {
        await withServiceErrorHandling(context: "fetch CurseForge game version list", fallback: []) {
            try await fetchGameVersionsThrowing()
        }
    }

    /// Fetches the list of supported game versions from CurseForge, throwing on failure.
    /// - Returns: An array of approved release game versions.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchGameVersionsThrowing() async throws -> [CurseForgeGameVersion] {
        let headers = getHeaders()
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.gameVersions, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeGameVersionsResponse.self, from: data)
        return result.data.filter { $0.approved && $0.version_type == "release" }
    }
}
