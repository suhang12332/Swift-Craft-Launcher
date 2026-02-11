//
//  GameNameGenerator.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import Foundation

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

// MARK: - GameNameGenerator
enum GameNameGenerator {
    /// 为 ModPack 下载生成默认游戏名称
    /// - Parameters:
    ///   - projectTitle: 项目标题
    ///   - gameVersion: 游戏版本
    ///   - includeTimestamp: 是否包含时间戳（默认 true）
    /// - Returns: 生成的游戏名称
    static func generateModPackName(
        projectTitle: String?,
        gameVersion: String,
        includeTimestamp: Bool = true
    ) -> String {
        let baseName = "\(projectTitle ?? "ModPack")-\(gameVersion)"

        if includeTimestamp {
            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            return "\(baseName)-\(timestamp)"
        }

        return baseName
    }

    /// 为 ModPack 导入生成默认游戏名称
    /// - Parameters:
    ///   - modPackName: 整合包名称
    ///   - modPackVersion: 整合包版本
    ///   - includeTimestamp: 是否包含时间戳（默认 true）
    /// - Returns: 生成的游戏名称
    static func generateImportName(
        modPackName: String,
        modPackVersion: String,
        includeTimestamp: Bool = true
    ) -> String {
        let baseName = "\(modPackName)-\(modPackVersion)"

        if includeTimestamp {
            let timestamp = DateFormatter.timestampFormatter.string(from: Date())
            return "\(baseName)-\(timestamp)"
        }

        return baseName
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
