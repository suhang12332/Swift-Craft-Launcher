//
//  CurseForgeService+Catalog.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides catalog operations for CurseForge categories.
extension CurseForgeService {
    /// Fetches the list of CurseForge categories, throwing on failure.
    /// - Returns: An array of categories.
    /// - Throws: A `GlobalError` if the request fails.
    static func fetchCategoriesThrowing() async throws -> [CurseForgeCategory] {
        let headers = getHeaders()
        let data = try await APIClient.get(url: URLConfig.API.CurseForge.categories, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeCategoriesResponse.self, from: data)
        return result.data
    }
}
