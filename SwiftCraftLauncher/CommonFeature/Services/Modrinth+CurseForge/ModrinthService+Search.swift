//
//  ModrinthService+Search.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides search operations for Modrinth projects.
extension ModrinthService {
    static func searchProjectsThrowing(
        facets: [[String]]? = nil,
        index: String,
        offset: Int = 0,
        limit: Int,
        query: String?,
    ) async throws -> ModrinthResult {
        var queryItems = [
            URLQueryItem(name: "index", value: index),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(min(limit, SearchPagination.modrinthMaxLimit))),
        ]

        if let query {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }

        if let facets {
            queryItems.append(
                try SearchRequestBuilder.jsonQueryItem(
                    name: "facets",
                    value: facets,
                    i18nKey: "error.validation.search_condition_encode_failed",
                    contextLabel: "Modrinth search facets",
                ),
            )
        }

        let url = try SearchRequestBuilder.makeURL(
            baseURL: URLConfig.API.Modrinth.search,
            queryItems: queryItems,
            urlErrorMessage: "Failed to build Modrinth search URL for index=\(index), offset=\(offset), limit=\(limit)",
        )

        let data = try await APIClient.get(url: url)

        let decoder = JSONDecoder()
        decoder.configureForModrinth()
        return try decoder.decode(ModrinthResult.self, from: data)
    }
}
