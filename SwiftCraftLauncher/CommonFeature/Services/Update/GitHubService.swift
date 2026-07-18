//
//  GitHubService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides access to GitHub API endpoints for contributors, acknowledgements, and announcements.
public class GitHubService: ObservableObject {
    init() { }

    /// Fetches the list of repository contributors.
    public func fetchContributors() async throws -> [GitHubContributor] {
        let url = URLConfig.API.GitHub.contributors()
        let data = try await APIClient.get(url: url)
        return try JSONDecoder().decode([GitHubContributor].self, from: data)
    }

    /// Fetches raw static contributor data as JSON.
    private func fetchStaticContributorsData() async throws -> Data {
        let url = URLConfig.API.GitHub.staticContributors()
        return try await APIClient.get(url: url)
    }

    /// Fetches decoded static contributor data.
    public func fetchStaticContributors<T: Decodable>() async throws -> T {
        let data = try await fetchStaticContributorsData()
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Fetches raw open source acknowledgements data as JSON.
    private func fetchAcknowledgementsData() async throws -> Data {
        let url = URLConfig.API.GitHub.acknowledgements()
        let headers = APIClient.DefaultHeaders.acceptJSON
        return try await APIClient.get(url: url, headers: headers)
    }

    /// Fetches decoded open source acknowledgements data.
    public func fetchAcknowledgements<T: Decodable>() async throws -> T {
        let data = try await fetchAcknowledgementsData()
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Fetches announcement data for the specified version and language.
    /// - Parameters:
    ///   - version: The application version number.
    ///   - language: The language code.
    /// - Returns: The announcement data, or `nil` if not found.
    public func fetchAnnouncement(
        version: String,
        language: String,
    ) async throws -> AnnouncementData? {
        let url = URLConfig.API.GitHub.announcement(
            version: version,
            language: language,
        )

        let headers = APIClient.DefaultHeaders.acceptJSON
        let data = try await APIClient.get(url: url, headers: headers)

        let announcementResponse = try JSONDecoder().decode(
            AnnouncementResponse.self,
            from: data,
        )

        guard announcementResponse.success else {
            throw GitHubServiceError.announcementNotSuccessful
        }

        return announcementResponse.data
    }
}

/// Errors that can occur during GitHub service operations.
public enum GitHubServiceError: Error {
    case httpError(statusCode: Int)
    case invalidResponse
    case announcementNotSuccessful
}
