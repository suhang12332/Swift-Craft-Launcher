//
//  CurseForgeService+Search.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides search operations for CurseForge projects.
extension CurseForgeService {
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
        pageSize: Int = SearchPagination.pageSize,
    ) async throws -> CurseForgeSearchResult {
        // CurseForge sort field: 6 = Last Updated
        let sortField = 6
        let sortOrder = "desc"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: String(gameId)),
            URLQueryItem(name: "index", value: String(index)),
            URLQueryItem(name: "pageSize", value: String(min(pageSize, SearchPagination.curseForgeMaxPageSize))),
        ]

        if let classId {
            queryItems.append(URLQueryItem(name: "classId", value: String(classId)))
        }

        if let categoryIds, !categoryIds.isEmpty {
            let stringIds = categoryIds.prefix(10).map(String.init)
            queryItems.append(
                try SearchRequestBuilder.jsonQueryItem(
                    name: "categoryIds",
                    value: stringIds,
                    i18nKey: "error.validation.encode_category_ids_failed",
                    contextLabel: "categoryIds",
                ),
            )
        } else if let categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: String(categoryId)))
        }

        if let gameVersions, !gameVersions.isEmpty {
            queryItems.append(
                try SearchRequestBuilder.jsonQueryItem(
                    name: "gameVersions",
                    value: Array(gameVersions.prefix(4)),
                    i18nKey: "error.validation.encode_game_versions_failed",
                    contextLabel: "gameVersions",
                ),
            )
        } else if let gameVersion {
            queryItems.append(URLQueryItem(name: "gameVersion", value: gameVersion))
        }

        if let rawSearchFilter = searchFilter?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !rawSearchFilter.isEmpty {
            let normalizedSearchFilter = rawSearchFilter
                .split { $0.isWhitespace }
                .map(String.init)
                .joined(separator: "+")
            queryItems.append(URLQueryItem(name: "searchFilter", value: normalizedSearchFilter))
        }

        queryItems.append(URLQueryItem(name: "sortField", value: String(sortField)))
        queryItems.append(URLQueryItem(name: "sortOrder", value: sortOrder))

        if let modLoaderTypes, !modLoaderTypes.isEmpty {
            queryItems.append(
                try SearchRequestBuilder.jsonQueryItem(
                    name: "modLoaderTypes",
                    value: modLoaderTypes.prefix(5).map(String.init),
                    i18nKey: "error.validation.encode_mod_loader_types_failed",
                    contextLabel: "modLoaderTypes",
                ),
            )
        } else if let modLoaderType {
            queryItems.append(URLQueryItem(name: "modLoaderType", value: String(modLoaderType)))
        }

        let url = try SearchRequestBuilder.makeURL(
            baseURL: URLConfig.API.CurseForge.search,
            queryItems: queryItems,
            urlErrorMessage: "Failed to build CurseForge search URL for index=\(index), pageSize=\(pageSize)",
        )

        let data = try await APIClient.get(url: url, headers: getHeaders())
        return try JSONDecoder().decode(CurseForgeSearchResult.self, from: data)
    }
}
