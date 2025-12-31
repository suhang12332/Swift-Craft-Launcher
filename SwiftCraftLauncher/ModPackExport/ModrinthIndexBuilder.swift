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

        // 获取加载器版本
        let loaderVersion = await LoaderVersionResolver.resolve(
            loaderType: loaderType,
            gameVersion: gameVersion,
            gameInfo: gameInfo
        )
        
        Logger.shared.info("导出整合包 - 加载器类型: \(loaderType), 版本: \(loaderVersion ?? "未找到")")

        // 构建依赖字典
        let dependencies = buildDependencies(
            gameVersion: gameVersion,
            loaderType: loaderType,
            loaderVersion: loaderVersion
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
        case "forge":
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
        case "fabric":
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
        case "quilt":
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
        case "neoforge":
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

/// 加载器版本解析器
enum LoaderVersionResolver {
    /// 解析加载器版本
    /// 优先从 modVersion 字段获取，如果不存在则尝试从已安装的加载器 mod 中推断
    static func resolve(
        loaderType: String,
        gameVersion: String,
        gameInfo: GameVersionInfo
    ) async -> String? {
        // 1. 尝试从 modVersion 字段获取
        if !gameInfo.modVersion.isEmpty {
            if isValidVersionFormat(gameInfo.modVersion) {
                return gameInfo.modVersion
            }
        }
        
        // 2. 尝试从已安装的加载器 mod 中推断版本
        let modsDir = AppPaths.modsDirectory(gameName: gameInfo.gameName)
        guard let modFiles = try? ResourceScanner.scanResourceDirectory(modsDir) else {
            return nil
        }
        
        // 根据加载器类型查找对应的加载器 mod
        let loaderModPatterns: [String]
        switch loaderType {
        case "fabric":
            loaderModPatterns = ["fabric-api"]
        case "forge":
            loaderModPatterns = ["forge", "minecraftforge"]
        case "quilt":
            loaderModPatterns = ["quilt-loader", "quilt-standard"]
        case "neoforge":
            loaderModPatterns = ["neoforge"]
        default:
            return nil
        }
        
        // 查找加载器 mod 文件
        for modFile in modFiles where loaderModPatterns.contains(where: { modFile.lastPathComponent.lowercased().contains($0) }) {
            let fileName = modFile.lastPathComponent.lowercased()
            // 尝试从文件名中提取版本号
            if let version = extractVersionFromFileName(fileName) {
                return version
            }

            // 如果文件名中没有版本，尝试从 Modrinth 获取
            if let modrinthInfo = await ModrinthResourceIdentifier.getModrinthInfo(for: modFile) {
                // 缓存包含 optional 的 server_side 和 client_side 信息
                cacheModrinthSideInfo(modrinthInfo: modrinthInfo, modFile: modFile)
                
                let versionName = modrinthInfo.version.name
                if let version = extractVersionFromString(versionName) {
                    return version
                }
                if !modrinthInfo.version.versionNumber.isEmpty {
                    return modrinthInfo.version.versionNumber
                }
            }
        }

        // 3. 对于 Fabric，尝试从启动参数中提取版本
        if loaderType == "fabric" {
            for arg in gameInfo.launchCommand where arg.contains("fabric-loader") {
                if let version = extractVersionFromString(arg) {
                    return version
                }
            }
        }
        
        return nil
    }

    /// 验证版本号格式是否有效
    private static func isValidVersionFormat(_ version: String) -> Bool {
        let pattern = #"^\d+\.\d+(\.\d+)?(-.*)?$"#
        return version.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// 从文件名中提取版本号
    private static func extractVersionFromFileName(_ fileName: String) -> String? {
        let patterns = [
            #"(\d+\.\d+\.\d+)"#,      // 1.2.3
            #"(\d+\.\d+)"#,            // 1.2
            #"v?(\d+\.\d+\.\d+)"#,     // v1.2.3
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
               let range = Range(match.range(at: 1), in: fileName) {
                return String(fileName[range])
            }
        }
        
        return nil
    }

    /// 从字符串中提取版本号
    private static func extractVersionFromString(_ string: String) -> String? {
        return extractVersionFromFileName(string.lowercased())
    }
    
    /// 缓存 Modrinth 项目的 server_side 和 client_side 信息
    /// 仅缓存包含 "optional" 值的数据
    private static func cacheModrinthSideInfo(
        modrinthInfo: ModrinthResourceIdentifier.ModrinthModInfo,
        modFile: URL
    ) {
        let projectDetail = modrinthInfo.projectDetail
        
        // 检查是否需要缓存（至少有一个是 optional）
        let shouldCache = projectDetail.clientSide == "optional" || projectDetail.serverSide == "optional"
        
        guard shouldCache else {
            return
        }
        
        // 使用文件 hash 作为缓存键
        guard let hash = try? SHA1Calculator.sha1(ofFileAt: modFile) else {
            return
        }
        
        // 构建缓存数据结构
        let sideInfo = ModrinthSideInfo(
            clientSide: projectDetail.clientSide,
            serverSide: projectDetail.serverSide,
            projectId: projectDetail.id
        )
        
        // 缓存到 AppCacheManager
        let cacheKey = "modrinth_side_\(hash)"
        AppCacheManager.shared.setSilently(
            namespace: "modrinth_side_info",
            key: cacheKey,
            value: sideInfo
        )
    }
}

/// Modrinth 项目的 server_side 和 client_side 信息缓存结构
private struct ModrinthSideInfo: Codable {
    let clientSide: String
    let serverSide: String
    let projectId: String
    
    enum CodingKeys: String, CodingKey {
        case clientSide = "client_side"
        case serverSide = "server_side"
        case projectId = "project_id"
    }
}

