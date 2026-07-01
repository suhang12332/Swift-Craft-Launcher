//
//  CurseForgeService+Catalog.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides catalog operations for CurseForge categories and game versions.
extension CurseForgeService {
    /// Fetches the list of CurseForge categories.
    /// - Returns: An array of categories, or an empty array on failure.
    static func fetchCategories() async -> [CurseForgeCategory] {
        do {
            return try await fetchCategoriesThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("获取 CurseForge 分类列表失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return []
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

    /// Fetches the list of supported game versions from CurseForge.
    /// - Returns: An array of game versions, or an empty array on failure.
    static func fetchGameVersions() async -> [CurseForgeGameVersion] {
        do {
            return try await fetchGameVersionsThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("获取 CurseForge 游戏版本列表失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return []
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
