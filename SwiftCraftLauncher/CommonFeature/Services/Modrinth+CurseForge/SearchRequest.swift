//
//  SearchRequest.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Pagination limits shared by the resource search backends.
enum SearchPagination {
    /// Number of results requested per page.
    static let pageSize = 20
    /// Modrinth's maximum accepted `limit`.
    static let modrinthMaxLimit = 100
    /// CurseForge's maximum accepted `pageSize`.
    static let curseForgeMaxPageSize = 50
}

/// Builds provider search URLs with consistent validation and error reporting.
enum SearchRequestBuilder {
    /// Assembles a URL from a base endpoint and query items.
    /// - Parameters:
    ///   - baseURL: The provider search endpoint.
    ///   - queryItems: The assembled query items.
    ///   - urlErrorMessage: Diagnostic detail used when the final URL cannot be built.
    /// - Returns: The request URL.
    /// - Throws: A ``GlobalError`` when the URL cannot be built.
    static func makeURL(
        baseURL: URL,
        queryItems: [URLQueryItem],
        urlErrorMessage: String,
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.url_components_build_failed",
                level: .notification,
                message: "Failed to build URLComponents from search URL: \(baseURL.absoluteString)",
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw GlobalError.validation(
                i18nKey: "error.validation.search_url_build_failed",
                level: .notification,
                message: urlErrorMessage,
            )
        }
        return url
    }

    /// Encodes an encodable value as a JSON string query item.
    /// - Parameters:
    ///   - name: The query item name.
    ///   - value: The value to encode.
    ///   - i18nKey: The error key used when encoding fails.
    ///   - contextLabel: Diagnostic label for the encoded value.
    /// - Returns: A query item holding the JSON string.
    /// - Throws: A ``GlobalError`` when the value cannot be encoded.
    static func jsonQueryItem(
        name: String,
        value: some Encodable,
        i18nKey: String,
        contextLabel: String,
    ) throws -> URLQueryItem {
        let data: Data
        do {
            data = try JSONEncoder().encode(value)
        } catch {
            throw GlobalError.validation(
                i18nKey: i18nKey,
                level: .notification,
                message: "Failed to encode \(contextLabel) to JSON: \(error.localizedDescription)",
            )
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw GlobalError.validation(
                i18nKey: i18nKey,
                level: .notification,
                message: "Failed to encode \(contextLabel) to JSON string: \(value)",
            )
        }
        return URLQueryItem(name: name, value: jsonString)
    }
}
