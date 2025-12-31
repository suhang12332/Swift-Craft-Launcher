//
//  ResourceProcessor.swift
//  SwiftCraftLauncher
//
//  Created by Auto on 2025/01/XX.
//

import Foundation

/// 资源处理器
/// 负责识别资源文件并决定是添加到索引还是复制到 overrides
enum ResourceProcessor {
    
    /// 处理结果
    struct ProcessResult {
        let indexFile: ModrinthIndexFile?
        let shouldCopyToOverrides: Bool
        let sourceFile: URL
        let relativePath: String
    }
    
    /// 处理单个资源文件
    /// - Parameters:
    ///   - file: 资源文件路径
    ///   - resourceType: 资源类型
    ///   - overridesDir: overrides 目录
    /// - Returns: 处理结果
    /// - Throws: 如果复制文件失败
    static func process(
        file: URL,
        resourceType: ResourceScanner.ResourceType,
        overridesDir: URL
    ) async throws -> ProcessResult {
        let relativePath = resourceType.rawValue
        let overridesSubDir = overridesDir.appendingPathComponent(relativePath)
        
        // 尝试从 Modrinth 获取信息
        var indexFile: ModrinthIndexFile? = nil
        if let modrinthInfo = await ModrinthResourceIdentifier.getModrinthInfo(for: file) {
            // 找到 Modrinth 项目，尝试创建索引文件
            indexFile = await createIndexFile(
                from: file,
                modrinthInfo: modrinthInfo,
                relativePath: relativePath
            )
        }
        
        // 如果成功创建了索引文件，不需要复制到 overrides
        if let indexFile = indexFile {
            return ProcessResult(
                indexFile: indexFile,
                shouldCopyToOverrides: false,
                sourceFile: file,
                relativePath: relativePath
            )
        }
        
        // 如果索引文件创建失败（Modrinth 识别不到、创建失败等），复制到 overrides
        let destPath = overridesSubDir.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.createDirectory(at: overridesSubDir, withIntermediateDirectories: true)
        
        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destPath.path) {
            try? FileManager.default.removeItem(at: destPath)
        }
        
        try FileManager.default.copyItem(at: file, to: destPath)
        return ProcessResult(
            indexFile: nil,
            shouldCopyToOverrides: true,
            sourceFile: file,
            relativePath: relativePath
        )
    }
    
    /// 创建索引文件
    private static func createIndexFile(
        from modFile: URL,
        modrinthInfo: ModrinthResourceIdentifier.ModrinthModInfo,
        relativePath: String
    ) async -> ModrinthIndexFile? {
        // 计算文件 hash
        guard let fileHash = try? SHA1Calculator.sha1(ofFileAt: modFile) else {
            return nil
        }
        
        // 找到匹配的文件
        let matchingFile = modrinthInfo.version.files.first(where: { file in
            file.hashes.sha1 == fileHash
        }) ?? modrinthInfo.version.files.first
        
        guard let matchingFile = matchingFile else {
            return nil
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: modFile.path)[.size] as? Int64) ?? 0
        
        // 设置 env 字段（根据 Modrinth 项目的 clientSide 和 serverSide）
        // 将 Modrinth 的 "optional" 映射为 "optional"，其他值映射为 "required"
        let clientEnv = modrinthInfo.projectDetail.clientSide == "optional" ? "optional" : "required"
        let serverEnv = modrinthInfo.projectDetail.serverSide == "optional" ? "optional" : "required"
        
        let env = ModrinthIndexFileEnv(
            client: clientEnv,
            server: serverEnv
        )
        
        return ModrinthIndexFile(
            path: "\(relativePath)/\(modFile.lastPathComponent)",
            hashes: ModrinthIndexFileHashes(from: [
                "sha1": matchingFile.hashes.sha1,
                "sha512": matchingFile.hashes.sha512
            ]),
            downloads: [matchingFile.url],
            fileSize: Int(fileSize),
            env: env,
            source: .modrinth
        )
    }
}

/// Modrinth 资源识别器
/// 负责从 Modrinth 获取资源信息
enum ModrinthResourceIdentifier {
    
    struct ModrinthModInfo {
        let projectDetail: ModrinthProjectDetail
        let version: ModrinthProjectDetailVersion
    }
    
    /// 尝试从 Modrinth 获取 mod 信息
    /// 始终通过 hash 查询 API
    static func getModrinthInfo(for modFile: URL) async -> ModrinthModInfo? {
        guard let hash = try? SHA1Calculator.sha1(ofFileAt: modFile) else {
            return nil
        }
        
        // 直接通过 hash 查询 API
        return await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                guard let detail = detail else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 需要找到匹配的版本
                Task {
                    do {
                        let versions = try await ModrinthService.fetchProjectVersionsThrowing(id: detail.id)
                        // 找到包含该 hash 的版本
                        if let matchingVersion = versions.first(where: { version in
                            version.files.contains { $0.hashes.sha1 == hash }
                        }) {
                            continuation.resume(returning: ModrinthModInfo(
                                projectDetail: detail,
                                version: matchingVersion
                            ))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

