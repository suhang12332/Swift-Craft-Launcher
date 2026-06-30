//
//  CurseForgeService+Private.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides internal CurseForge API request and parsing utilities.
extension CurseForgeService {
    /// Fetches file details from a specified URL.
    /// - Parameter urlString: The API endpoint URL.
    /// - Returns: The file details.
    /// - Throws: A network or parsing error.
    static func tryFetchFileDetail(from urlString: String) async throws -> CurseForgeModFileDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification,
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        let result = try JSONDecoder().decode(CurseForgeFileResponse.self, from: data)
        return result.data
    }

    /// Fetches mod details from a specified URL.
    /// - Parameter urlString: The API endpoint URL.
    /// - Returns: The mod details.
    /// - Throws: A network or parsing error.
    static func tryFetchModDetail(from urlString: String) async throws -> CurseForgeModDetail {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification,
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        let result = try JSONDecoder().decode(CurseForgeModDetailResponse.self, from: data)
        return result.data
    }

    /// Fetches the HTML description for a mod from a specified URL.
    /// - Parameter urlString: The API endpoint URL.
    /// - Returns: The HTML-formatted description content.
    /// - Throws: A network or parsing error.
    static func tryFetchModDescription(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的镜像 API URL",
                i18nKey: "error.network.url",
                level: .notification,
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)

        let result = try JSONDecoder().decode(CurseForgeModDescriptionResponse.self, from: data)
        return result.data
    }

    /// Parses a CurseForge identifier into its numeric ID and normalized form.
    static func parseCurseForgeId(_ id: String) throws -> (modId: Int, normalized: String) {
        let cleanId = id.replacingOccurrences(of: "cf-", with: "")
        guard let modId = Int(cleanId) else {
            throw GlobalError.validation(
                chineseMessage: "无效的项目 ID",
                i18nKey: "error.validation.invalid_project_id",
                level: .notification,
            )
        }
        let normalizedId = id.hasPrefix("cf-") ? id : "cf-\(cleanId)"
        return (modId, normalizedId)
    }

    static func fetchFingerprintMatchesThrowing(fingerprint: UInt32) async throws -> CurseForgeFingerprintMatchesResponse {
        let url = URLConfig.API.CurseForge.fingerprints
        let headers = getHeaders()

        let requestBody = CurseForgeFingerprintMatchesRequest(fingerprints: [fingerprint])
        let body = try JSONEncoder().encode(requestBody)

        let data = try await APIClient.post(url: url, body: body, headers: headers)
        return try JSONDecoder().decode(CurseForgeFingerprintMatchesResponse.self, from: data)
    }
}

/// Represents a CurseForge API file response.
struct CurseForgeFileResponse: Codable {
    let data: CurseForgeModFileDetail
}
