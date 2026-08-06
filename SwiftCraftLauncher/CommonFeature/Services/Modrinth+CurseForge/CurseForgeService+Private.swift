//
//  CurseForgeService+Private.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A CurseForge API response that wraps a `data` payload.
protocol CurseForgeResponseDecodable: Decodable {
    associatedtype Data

    var data: Data { get }
}

extension CurseForgeModDetailResponse: CurseForgeResponseDecodable {}

extension CurseForgeModDescriptionResponse: CurseForgeResponseDecodable {}

/// Provides internal CurseForge API request and parsing utilities.
extension CurseForgeService {
    /// Fetches and decodes a CurseForge API response from a specified URL.
    /// - Parameter urlString: The API endpoint URL.
    /// - Returns: The unwrapped `data` payload.
    /// - Throws: A network or parsing error.
    static func tryFetch<T: CurseForgeResponseDecodable>(_: T.Type, from urlString: String) async throws -> T.Data {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                i18nKey: "error.network.url",
                level: .notification,
                message: "Invalid CurseForge URL: \(urlString)",
            )
        }

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(T.self, from: data)
        return result.data
    }

    /// Parses a CurseForge identifier into its numeric ID and normalized form.
    static func parseCurseForgeId(_ id: String) throws -> (modId: Int, normalized: String) {
        try id.asProjectId.parseCurseForgeId()
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
struct CurseForgeFileResponse: CurseForgeResponseDecodable {
    let data: CurseForgeModFileDetail
}
