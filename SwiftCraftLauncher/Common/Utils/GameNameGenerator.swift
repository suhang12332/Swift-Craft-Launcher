//
//  GameNameGenerator.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import Foundation

// MARK: - GameNameGenerator
enum GameNameGenerator {
    /// 为 ModPack 下载生成默认游戏名称
    /// - Parameters:
    ///   - projectTitle: 项目标题
    ///   - gameVersion: 游戏版本
    /// - Returns: 生成的游戏名称
    static func generateModPackName(
        projectTitle: String?,
        gameVersion: String
    ) -> String {
        return "\(projectTitle ?? "ModPack")-\(gameVersion)"
    }

    /// 为 ModPack 导入生成默认游戏名称
    /// - Parameters:
    ///   - modPackName: 整合包名称
    ///   - modPackVersion: 整合包版本
    /// - Returns: 生成的游戏名称
    static func generateImportName(
        modPackName: String,
        modPackVersion: String
    ) -> String {
        return "\(modPackName)-\(modPackVersion)"
    }

    /// 为普通游戏创建生成默认游戏名称
    /// - Parameters:
    ///   - gameVersion: 游戏版本
    ///   - modLoader: 模组加载器
    /// - Returns: 生成的游戏名称
    static func generateGameName(
        gameVersion: String,
        modLoader: String
    ) -> String {
        let loaderName = modLoader.lowercased() == "vanilla" ? "" : "-\(modLoader)"
        return "\(gameVersion)\(loaderName)"
    }
}
