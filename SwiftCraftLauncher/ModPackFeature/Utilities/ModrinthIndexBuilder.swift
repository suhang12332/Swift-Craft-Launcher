//
//  ModrinthIndexBuilder.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation

/// Modrinth 索引构建器
/// 负责构建 modrinth.index.json 文件
enum ModrinthIndexBuilder {
    /// 构建索引 JSON 字符串
    /// - Parameters:
    ///   - gameInfo: 游戏信息
    ///   - modPackName: 整合包名称
    ///   - modPackVersion: 整合包版本
    ///   - summary: 整合包描述
    ///   - files: 索引文件列表
    /// - Returns: JSON 字符串
    static func build(
        gameInfo: GameVersionInfo,
        modPackName: String,
        modPackVersion: String,
        summary: String?,
        files: [ModrinthIndexFile]
    ) async throws -> String {
        let gameVersion = gameInfo.gameVersion
        let loaderType = gameInfo.modLoader.lowercased()

        Logger.shared.info("导出整合包 - 加载器类型: \(loaderType), 版本: \(gameInfo.modVersion)")

        // 构建依赖字典
        let dependencies = buildDependencies(
            gameVersion: gameVersion,
            loaderType: loaderType,
            loaderVersion: gameInfo.modVersion
        )

        // 构建 JSON 字典
        var jsonDict: [String: Any] = [
            "formatVersion": 1,
            "game": "minecraft",
            "versionId": modPackVersion,
            "name": modPackName,
        ]

        if let summary = summary {
            jsonDict["summary"] = summary
        }

        // 编码 files，排除非标准字段
        var filesArray: [[String: Any]] = []
        for file in files {
            var fileDict: [String: Any] = [
                "path": file.path,
                "hashes": [
                    "sha1": file.hashes.sha1 ?? "",
                    "sha512": file.hashes.sha512 ?? "",
                ],
                "downloads": file.downloads,
                "fileSize": file.fileSize,
            ]

            // 添加 env 字段（如果存在）
            if let env = file.env {
                var envDict: [String: String] = [:]
                if let client = env.client {
                    envDict["client"] = client
                }
                if let server = env.server {
                    envDict["server"] = server
                }
                if !envDict.isEmpty {
                    fileDict["env"] = envDict
                }
            }

            filesArray.append(fileDict)
        }
        jsonDict["files"] = filesArray

        // 编码 dependencies
        var depsDict: [String: Any] = [:]
        if let minecraft = dependencies.minecraft {
            depsDict["minecraft"] = minecraft
        }
        if let forgeLoader = dependencies.forgeLoader {
            depsDict["forge-loader"] = forgeLoader
        }
        if let fabricLoader = dependencies.fabricLoader {
            depsDict["fabric-loader"] = fabricLoader
        }
        if let quiltLoader = dependencies.quiltLoader {
            depsDict["quilt-loader"] = quiltLoader
        }
        if let neoforgeLoader = dependencies.neoforgeLoader {
            depsDict["neoforge-loader"] = neoforgeLoader
        }
        jsonDict["dependencies"] = depsDict

        // 转换为 JSON 字符串
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonDict,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    /// 构建依赖字典
    private static func buildDependencies(
        gameVersion: String,
        loaderType: String,
        loaderVersion: String?
    ) -> ModrinthIndexDependencies {
        switch loaderType {
        case GameLoader.forge.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: loaderVersion,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.fabric.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: loaderVersion,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.quilt.rawValue:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: loaderVersion,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        case GameLoader.neoforge.displayName:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: loaderVersion,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        default:
            return ModrinthIndexDependencies(
                minecraft: gameVersion,
                forgeLoader: nil,
                fabricLoader: nil,
                quiltLoader: nil,
                neoforgeLoader: nil,
                forge: nil,
                fabric: nil,
                quilt: nil,
                neoforge: nil,
                dependencies: nil
            )
        }
    }
}
