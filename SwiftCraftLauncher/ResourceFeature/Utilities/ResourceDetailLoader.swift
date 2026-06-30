//
//  ResourceDetailLoader.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Loads project details and compatible game information before presenting a detail sheet.
enum ResourceDetailLoader {
    /// Loads project details and determines compatible games for a standard resource.
    /// - Parameters:
    ///   - projectId: The project identifier.
    ///   - gameRepository: The game repository providing local game data.
    ///   - resourceType: The type of resource.
    ///   - skipCompatibleGameResolution: When true, fetches only the project detail without resolving compatible games.
    /// - Returns: A tuple of project detail and compatible game versions, or nil on failure.
    static func loadProjectDetail(
        projectId: String,
        gameRepository: GameRepository,
        resourceType: String,
        skipCompatibleGameResolution: Bool = false
    ) async -> (detail: ModrinthProjectDetail, compatibleGames: [GameVersionInfo])? {

        let isServer = resourceType == ResourceType.minecraftJavaServer.rawValue
        guard let detail = await ModrinthService.fetchProjectDetails(id: projectId, type: isServer ? resourceType : "") else {
            AppServices.errorHandler.handle(
                GlobalError.resource(
                    chineseMessage: "无法获取项目详情",
                    i18nKey: "error.resource.project_details_not_found",
                    level: .notification
                )
            )
            return nil
        }
        if skipCompatibleGameResolution {
            return (detail, [])
        }
        let compatibleGames = await filterCompatibleGames(
            detail: detail,
            gameRepository: gameRepository,
            resourceType: resourceType,
            projectId: projectId
        )
        let finalGames: [GameVersionInfo]
        if isServer {
            finalGames = await AppServices.serverAddressService.filterGamesWithoutExistingServer(
                detail: detail,
                games: compatibleGames
            )
        } else {
            finalGames = compatibleGames
        }

        return (detail, finalGames)
    }

    /// Loads a modpack project detail.
    /// - Parameter projectId: The project identifier.
    /// - Returns: The project detail, or nil on failure.
    static func loadModPackDetail(projectId: String) async -> ModrinthProjectDetail? {
        guard let detail = await ModrinthService.fetchProjectDetails(id: projectId) else {
            AppServices.errorHandler.handle(GlobalError.resource(
                chineseMessage: "无法获取整合包项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            ))
            return nil
        }
        return detail
    }
}
