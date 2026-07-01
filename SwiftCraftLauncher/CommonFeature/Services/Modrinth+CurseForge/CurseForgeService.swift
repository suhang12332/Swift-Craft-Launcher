//
//  CurseForgeService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides a unified interface for accessing the CurseForge API.
enum CurseForgeService {
    static func getHeaders() -> [String: String] {
        var headers: [String: String] = APIClient.DefaultHeaders.acceptJSON
        if let apiKey = AppConstants.curseForgeAPIKey {
            headers[APIClient.Header.xAPIKey] = apiKey
        }
        return headers
    }

    /// Fetches file details for a CurseForge project file.
    /// - Parameters:
    ///   - projectId: The CurseForge project identifier.
    ///   - fileId: The file identifier.
    /// - Returns: The file details, or `nil` if the request fails.
    static func fetchFileDetail(projectId: Int, fileId: Int) async -> CurseForgeModFileDetail? {
        do {
            return try await fetchFileDetailThrowing(projectId: projectId, fileId: fileId)
        } catch {
            Logger.shared.error("获取 CurseForge 文件详情失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches file details for a CurseForge project file, throwing on failure.
    /// - Parameters:
    ///   - projectId: The CurseForge project identifier.
    ///   - fileId: The file identifier.
    /// - Returns: The file details.
    /// - Throws: A network or parsing error.
    static func fetchFileDetailThrowing(projectId: Int, fileId: Int) async throws -> CurseForgeModFileDetail {
        let url = URLConfig.API.CurseForge.fileDetail(projectId: projectId, fileId: fileId)

        return try await tryFetchFileDetail(from: url.absoluteString)
    }

    /// Fetches mod details from CurseForge.
    /// - Parameter modId: The mod identifier.
    /// - Returns: The mod details, or `nil` if the request fails.
    static func fetchModDetail(modId: Int) async -> CurseForgeModDetail? {
        do {
            return try await fetchModDetailThrowing(modId: modId)
        } catch {
            Logger.shared.error("获取 CurseForge 模组详情失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches mod details from CurseForge, throwing on failure.
    /// - Parameter modId: The mod identifier.
    /// - Returns: The mod details.
    /// - Throws: A network or parsing error.
    static func fetchModDetailThrowing(modId: Int) async throws -> CurseForgeModDetail {
        let url = URLConfig.API.CurseForge.modDetail(modId: modId)

        return try await tryFetchModDetail(from: url.absoluteString)
    }

    /// Fetches the HTML description for a CurseForge mod, throwing on failure.
    /// - Parameter modId: The mod identifier.
    /// - Returns: The HTML-formatted description content.
    /// - Throws: A network or parsing error.
    static func fetchModDescriptionThrowing(modId: Int) async throws -> String {
        let url = URLConfig.API.CurseForge.modDescription(modId: modId)

        return try await tryFetchModDescription(from: url.absoluteString)
    }

    /// Fetches the file list for a CurseForge project.
    /// - Parameters:
    ///   - projectId: The CurseForge project identifier.
    ///   - gameVersion: An optional game version filter.
    ///   - modLoaderType: An optional mod loader type filter.
    /// - Returns: The file list, or `nil` if the request fails.
    static func fetchProjectFiles(projectId: Int, gameVersion: String? = nil, modLoaderType: Int? = nil) async -> [CurseForgeModFileDetail]? {
        do {
            return try await fetchProjectFilesThrowing(projectId: projectId, gameVersion: gameVersion, modLoaderType: modLoaderType)
        } catch {
            Logger.shared.error("获取 CurseForge 项目文件列表失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches the file list for a CurseForge project, throwing on failure.
    /// - Parameters:
    ///   - projectId: The CurseForge project identifier.
    ///   - gameVersion: An optional game version filter.
    ///   - modLoaderType: An optional mod loader type filter.
    /// - Returns: The file list.
    /// - Throws: A network or parsing error.
    static func fetchProjectFilesThrowing(
        projectId: Int,
        gameVersion: String? = nil,
        modLoaderType: Int? = nil,
    ) async throws -> [CurseForgeModFileDetail] {
        let url = URLConfig.API.CurseForge.projectFiles(
            projectId: projectId,
            gameVersion: gameVersion,
            modLoaderType: modLoaderType,
        )

        let headers = getHeaders()
        let data = try await APIClient.get(url: url, headers: headers)
        let result = try JSONDecoder().decode(CurseForgeFilesResult.self, from: data)
        return result.data
    }
}
