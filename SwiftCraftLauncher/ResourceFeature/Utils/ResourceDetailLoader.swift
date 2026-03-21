//
//  ResourceDetailLoader.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation

/// 资源详情加载器
/// 负责在打开 sheet 前加载项目详情和兼容游戏信息
enum ResourceDetailLoader {
    /// 加载普通资源的详情和兼容游戏列表
    /// - Parameters:
    ///   - projectId: 项目 ID
    ///   - gameRepository: 游戏仓库
    ///   - resourceType: 资源类型
    /// - Returns: 项目详情和兼容游戏列表的元组，如果加载失败则返回 nil
    static func loadProjectDetail(
        projectId: String,
        gameRepository: GameRepository,
        resourceType: String
    ) async -> (detail: ModrinthProjectDetail, compatibleGames: [GameVersionInfo])? {

        let isServer = resourceType == ResourceType.minecraftJavaServer.rawValue
        let detail: ModrinthProjectDetail?
        if isServer {
            guard let v3 = await ModrinthService.fetchProjectDetailsV3(id: projectId) else {
                GlobalErrorHandler.shared.handle(
                    GlobalError.resource(
                        chineseMessage: "无法获取服务器项目详情",
                        i18nKey: "error.resource.server_project_details_not_found",
                        level: .notification
                    )
                )
                return nil
            }
            detail = ModrinthProjectDetail.fromV3(v3)
        } else {
            guard let v2 = await ModrinthService.fetchProjectDetails(id: projectId) else {
                GlobalErrorHandler.shared.handle(
                    GlobalError.resource(
                        chineseMessage: "无法获取项目详情",
                        i18nKey: "error.resource.project_details_not_found",
                        level: .notification
                    )
                )
                return nil
            }
            detail = v2
        }
        guard let detail else { return nil }
        let compatibleGames = await filterCompatibleGames(
            detail: detail,
            gameRepository: gameRepository,
            resourceType: resourceType,
            projectId: projectId
        )
        let finalGames: [GameVersionInfo]
        if isServer {
            finalGames = await ServerAddressService.shared.filterGamesWithoutExistingServer(
                detail: detail,
                games: compatibleGames
            )
        } else {
            finalGames = compatibleGames
        }

        return (detail, finalGames)
    }

    /// 加载整合包详情
    /// - Parameter projectId: 项目 ID
    /// - Returns: 项目详情，如果加载失败则返回 nil
    static func loadModPackDetail(projectId: String) async -> ModrinthProjectDetail? {
        guard let detail = await ModrinthService.fetchProjectDetails(id: projectId) else {
            GlobalErrorHandler.shared.handle(GlobalError.resource(
                chineseMessage: "无法获取整合包项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            ))
            return nil
        }
        return detail
    }
}
