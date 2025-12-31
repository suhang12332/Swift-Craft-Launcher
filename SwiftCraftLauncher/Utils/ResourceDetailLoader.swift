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
        guard let detail = await ModrinthService.fetchProjectDetails(id: projectId) else {
            GlobalErrorHandler.shared.handle(GlobalError.resource(
                chineseMessage: "无法获取项目详情",
                i18nKey: "error.resource.project_details_not_found",
                level: .notification
            ))
            return nil
        }

        // 检测兼容游戏
        let compatibleGames = await filterCompatibleGames(
            detail: detail,
            gameRepository: gameRepository,
            resourceType: resourceType,
            projectId: projectId
        )

        return (detail, compatibleGames)
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
