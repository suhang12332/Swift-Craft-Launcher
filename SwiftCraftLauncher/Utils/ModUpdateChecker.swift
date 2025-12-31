//
//  ModUpdateChecker.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import Foundation

/// Mod 更新检测器
/// 用于检测本地安装的 mod 是否有新版本可用
enum ModUpdateChecker {
    
    /// 检测结果
    struct UpdateCheckResult {
        /// 是否有新版本
        let hasUpdate: Bool
        /// 当前安装的版本 hash
        let currentHash: String?
        /// 最新版本的 hash
        let latestHash: String?
        /// 最新版本信息
        let latestVersion: ModrinthProjectDetailVersion?
    }
    
    /// 检测本地 mod 是否有新版本
    /// - Parameters:
    ///   - project: Modrinth 项目信息
    ///   - gameInfo: 游戏信息
    ///   - resourceType: 资源类型（mod, datapack, shader, resourcepack）
    /// - Returns: 更新检测结果
    static func checkForUpdate(
        project: ModrinthProject,
        gameInfo: GameVersionInfo,
        resourceType: String
    ) async -> UpdateCheckResult {
        // 如果是本地文件（projectId 以 "local_" 或 "file_" 开头），不检测更新
        if project.projectId.hasPrefix("local_") || project.projectId.hasPrefix("file_") {
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: nil,
                latestHash: nil,
                latestVersion: nil
            )
        }
        
        // 1. 获取本地文件的 hash
        guard let resourceDir = AppPaths.resourceDirectory(
            for: resourceType,
            gameName: gameInfo.gameName
        ) else {
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: nil,
                latestHash: nil,
                latestVersion: nil
            )
        }
        
        // 获取当前安装的文件 hash
        let currentHash = await getCurrentInstalledHash(
            project: project,
            resourceDir: resourceDir
        )
        
        guard let currentHash = currentHash else {
            // 如果无法获取当前 hash，认为没有更新
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: nil,
                latestHash: nil,
                latestVersion: nil
            )
        }
        
        // 2. 获取最新兼容版本
        let loaderFilters = [gameInfo.modLoader.lowercased()]
        let versionFilters = [gameInfo.gameVersion]
        
        do {
            let versions = try await ModrinthService.fetchProjectVersionsFilter(
                id: project.projectId,
                selectedVersions: versionFilters,
                selectedLoaders: loaderFilters,
                type: resourceType
            )
            
            // 获取最新版本（第一个版本通常是最新的）
            guard let latestVersion = versions.first,
                  let primaryFile = ModrinthService.filterPrimaryFiles(
                      from: latestVersion.files
                  ) else {
                return UpdateCheckResult(
                    hasUpdate: false,
                    currentHash: currentHash,
                    latestHash: nil,
                    latestVersion: nil
                )
            }
            
            let latestHash = primaryFile.hashes.sha1
            
            // 3. 比较 hash
            let hasUpdate = currentHash != latestHash
            
            return UpdateCheckResult(
                hasUpdate: hasUpdate,
                currentHash: currentHash,
                latestHash: latestHash,
                latestVersion: latestVersion
            )
        } catch {
            Logger.shared.error("检测 mod 更新失败: \(error.localizedDescription)")
            return UpdateCheckResult(
                hasUpdate: false,
                currentHash: currentHash,
                latestHash: nil,
                latestVersion: nil
            )
        }
    }
    
    /// 获取当前安装的文件 hash
    /// - Parameters:
    ///   - project: Modrinth 项目信息
    ///   - resourceDir: 资源目录
    /// - Returns: 当前安装的文件 hash，如果未找到则返回 nil
    private static func getCurrentInstalledHash(
        project: ModrinthProject,
        resourceDir: URL
    ) async -> String? {
        // 方法1: 通过文件名查找（如果 project 有 fileName）
        if let fileName = project.fileName {
            let fileURL = resourceDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return ModScanner.sha1Hash(of: fileURL)
            }
            
            // 也检查 .disabled 版本
            let disabledFileName = fileName + ".disabled"
            let disabledFileURL = resourceDir.appendingPathComponent(disabledFileName)
            if FileManager.default.fileExists(atPath: disabledFileURL.path) {
                return ModScanner.sha1Hash(of: disabledFileURL)
            }
        }
        
        // 方法2: 通过项目 ID 查找（扫描目录）
        // 如果项目有 projectId，尝试通过扫描找到匹配的文件
        if !project.projectId.isEmpty {
            let localDetails = ModScanner.shared.localModDetails(in: resourceDir)
            if let matchingDetail = localDetails.first(where: { $0.detail?.id == project.projectId }) {
                return matchingDetail.hash
            }
        }
        
        return nil
    }
}

