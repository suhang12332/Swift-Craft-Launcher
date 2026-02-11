//
//  ResourceInstallationChecker.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/28.
//

import Foundation

/// 资源安装状态检查器
/// 负责检查资源是否已安装在指定游戏中
enum ResourceInstallationChecker {
    /// 检查资源在服务端模式下是否已安装
    /// - Parameters:
    ///   - project: Modrinth 项目
    ///   - resourceType: 资源类型
    ///   - installedHashes: 已安装资源的 hash 集合
    ///   - selectedVersions: 选中的游戏版本列表
    ///   - selectedLoaders: 选中的加载器列表
    ///   - gameInfo: 游戏信息（可选，用于兜底）
    /// - Returns: 是否已安装
    static func checkInstalledStateForServerMode(
        project: ModrinthProject,
        resourceType: String,
        installedHashes: Set<String>,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?
    ) async -> Bool {
        guard !installedHashes.isEmpty else { return false }

        // 构造版本/loader 过滤条件（优先使用用户选择，其次使用当前游戏信息）
        let versionFilters: [String] = {
            if !selectedVersions.isEmpty {
                return selectedVersions
            }
            if let gameInfo = gameInfo {
                return [gameInfo.gameVersion]
            }
            return []
        }()

        let loaderFilters: [String] = {
            if !selectedLoaders.isEmpty {
                return selectedLoaders.map { $0.lowercased() }
            }
            if let gameInfo = gameInfo {
                return [gameInfo.modLoader.lowercased()]
            }
            return []
        }()

        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: project.projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType
            )

            for version in versions {
                guard
                    let primaryFile = ModrinthService.filterPrimaryFiles(
                        from: version.files
                    )
                else { continue }

                if installedHashes.contains(primaryFile.hashes.sha1) {
                    return true
                }
            }
        } catch {
            Logger.shared.error(
                "获取项目版本以检查安装状态失败: \(error.localizedDescription)"
            )
        }

        return false
    }
}
