//
//  ResourceScanner.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation

/// 资源扫描器
/// 负责扫描游戏实例中的所有资源文件（mods, datapacks, resourcepacks, shaderpacks）
enum ResourceScanner {
    /// 资源类型
    enum ResourceType: String, CaseIterable {
        case mods = "mods"
        case datapacks = "datapacks"
        case resourcepacks = "resourcepacks"
        case shaderpacks = "shaderpacks"
    }

    /// 扫描结果
    struct ScanResult {
        let type: ResourceType
        let files: [URL]
    }

    /// 扫描所有资源文件
    /// - Parameter gameInfo: 游戏信息
    /// - Returns: 按类型分组的扫描结果
    static func scanAllResources(gameInfo: GameVersionInfo) throws -> [ResourceType: [URL]] {
        var results: [ResourceType: [URL]] = [:]

        for resourceType in ResourceType.allCases {
            let directory = getDirectory(for: resourceType, gameName: gameInfo.gameName)
            let files = try scanResourceDirectory(directory)
            results[resourceType] = files
        }

        return results
    }

    /// 获取资源类型对应的目录路径
    private static func getDirectory(for type: ResourceType, gameName: String) -> URL {
        switch type {
        case .mods:
            return AppPaths.modsDirectory(gameName: gameName)
        case .datapacks:
            return AppPaths.datapacksDirectory(gameName: gameName)
        case .resourcepacks:
            return AppPaths.resourcepacksDirectory(gameName: gameName)
        case .shaderpacks:
            return AppPaths.shaderpacksDirectory(gameName: gameName)
        }
    }

    /// 扫描单个资源目录
    /// - Parameter directory: 目录路径
    /// - Returns: 找到的资源文件列表
    static func scanResourceDirectory(_ directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return files.filter { file in
            // 包含 .jar 和 .zip 文件，排除 .disabled 文件
            let ext = file.pathExtension.lowercased()
            return (ext == "jar" || ext == "zip") && !file.lastPathComponent.hasSuffix(".disabled")
        }
    }

    /// 计算总资源文件数
    /// - Parameter results: 扫描结果
    /// - Returns: 总文件数
    static func totalFileCount(_ results: [ResourceType: [URL]]) -> Int {
        results.values.reduce(0) { $0 + $1.count }
    }
}
