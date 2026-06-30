//
//  CurseForgeService+Search.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides search operations for CurseForge projects.
extension CurseForgeService {

    /// Searches CurseForge projects.
    /// - Parameters:
    ///   - gameId: The game identifier (432 for Minecraft).
    ///   - classId: An optional content type identifier.
    ///   - categoryId: An optional category identifier (overridden by `categoryIds`).
    ///   - categoryIds: An optional array of category identifiers (overrides `categoryId`, max 10).
    ///   - gameVersion: An optional game version (overridden by `gameVersions`).
    ///   - gameVersions: An optional array of game versions (overrides `gameVersion`, max 4).
    ///   - searchFilter: An optional search keyword.
    ///   - modLoaderType: An optional mod loader type (overridden by `modLoaderTypes`).
    ///   - modLoaderTypes: An optional array of mod loader types (overrides `modLoaderType`, max 5).
    ///   - index: The page index.
    ///   - pageSize: The number of results per page.
    /// - Returns: The search results, or empty results on failure.
    static func searchProjects(
        gameId: Int = 432,
        classId: Int? = nil,
        categoryId: Int? = nil,
        categoryIds: [Int]? = nil,
        gameVersion: String? = nil,
        gameVersions: [String]? = nil,
        searchFilter: String? = nil,
        modLoaderType: Int? = nil,
        modLoaderTypes: [Int]? = nil,
        index: Int = 0,
        pageSize: Int = 20
    ) async -> CurseForgeSearchResult {
        do {
            return try await searchProjectsThrowing(
                gameId: gameId,
                classId: classId,
                categoryId: categoryId,
                categoryIds: categoryIds,
                gameVersion: gameVersion,
                gameVersions: gameVersions,
                searchFilter: searchFilter,
                modLoaderType: modLoaderType,
                modLoaderTypes: modLoaderTypes,
                index: index,
                pageSize: pageSize
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索 CurseForge 项目失败: \(globalError.chineseMessage)")
            AppServices.errorHandler.handle(globalError)
            return CurseForgeSearchResult(data: [], pagination: nil)
        }
    }

    /// Searches CurseForge projects, throwing on failure.
    /// - Parameters:
    ///   - gameId: The game identifier (432 for Minecraft).
    ///   - classId: An optional content type identifier.
    ///   - categoryId: An optional category identifier (overridden by `categoryIds`).
    ///   - categoryIds: An optional array of category identifiers (overrides `categoryId`, max 10).
    ///   - gameVersion: An optional game version (overridden by `gameVersions`).
    ///   - gameVersions: An optional array of game versions (overrides `gameVersion`, max 4).
    ///   - searchFilter: An optional search keyword (whitespace is folded and joined with "+").
    ///   - modLoaderType: An optional mod loader type (overridden by `modLoaderTypes`).
    ///   - modLoaderTypes: An optional array of mod loader types (overrides `modLoaderType`, max 5).
    ///   - index: The page index.
    ///   - pageSize: The number of results per page.
    /// - Returns: The search results.
    /// - Throws: A `GlobalError` if the request fails.
    static func searchProjectsThrowing(
        gameId: Int = 432,
        classId: Int? = nil,
        categoryId: Int? = nil,
        categoryIds: [Int]? = nil,
        gameVersion: String? = nil,
        gameVersions: [String]? = nil,
        searchFilter: String? = nil,
        modLoaderType: Int? = nil,
        modLoaderTypes: [Int]? = nil,
        index: Int = 0,
        pageSize: Int = 20
    ) async throws -> CurseForgeSearchResult {
        let effectiveSortField = 6
        let effectiveSortOrder = "desc"

        var components = URLComponents(
            url: URLConfig.API.CurseForge.search,
            resolvingAgainstBaseURL: true
        )

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: String(gameId)),
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "pageSize", value: String(min(pageSize, 50))),
        ]

        if let classId = classId {
            queryItems.append(URLQueryItem(name: "classId", value: String(classId)))
        }

        if let categoryIds = categoryIds, !categoryIds.isEmpty {
            let limitedCategoryIds = Array(categoryIds.prefix(10))
            let stringIds = limitedCategoryIds.map { String($0) }
            let data = try JSONEncoder().encode(stringIds)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 categoryIds 失败",
                    i18nKey: "error.validation.encode_category_ids_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "categoryIds", value: jsonArrayString))
        } else if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: String(categoryId)))
        }

        if let gameVersions = gameVersions, !gameVersions.isEmpty {
            let limitedGameVersions = Array(gameVersions.prefix(4))
            let data = try JSONEncoder().encode(limitedGameVersions)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 gameVersions 失败",
                    i18nKey: "error.validation.encode_game_versions_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "gameVersions", value: jsonArrayString))
        } else if let gameVersion = gameVersion {
            queryItems.append(URLQueryItem(name: "gameVersion", value: gameVersion))
        }

        if let rawSearchFilter = searchFilter?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !rawSearchFilter.isEmpty {
            let components = rawSearchFilter
                .split { $0.isWhitespace }
                .map(String.init)
            let normalizedSearchFilter = components.joined(separator: "+")
            queryItems.append(URLQueryItem(name: "searchFilter", value: normalizedSearchFilter))
        }

        queryItems.append(URLQueryItem(name: "sortField", value: String(effectiveSortField)))
        queryItems.append(URLQueryItem(name: "sortOrder", value: effectiveSortOrder))

        if let modLoaderTypes = modLoaderTypes, !modLoaderTypes.isEmpty {
            let limitedModLoaderTypes = Array(modLoaderTypes.prefix(5))
            let stringTypes = limitedModLoaderTypes.map { String($0) }
            let data = try JSONEncoder().encode(stringTypes)
            guard let jsonArrayString = String(data: data, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "编码 modLoaderTypes 失败",
                    i18nKey: "error.validation.encode_mod_loader_types_failed",
                    level: .notification
                )
            }
            queryItems.append(URLQueryItem(name: "modLoaderTypes", value: jsonArrayString))
        } else if let modLoaderType = modLoaderType {
            queryItems.append(URLQueryItem(name: "modLoaderType", value: String(modLoaderType)))
        }

        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw GlobalError.validation(
                chineseMessage: "构建搜索URL失败",
                i18nKey: "error.validation.search_url_build_failed",
                level: .notification
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeSearchResult.self, from: data)

        return result
    }
}
