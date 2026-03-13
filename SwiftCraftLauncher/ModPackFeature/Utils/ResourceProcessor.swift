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
        /// overrides 目录中的相对路径（如 "mods" / "datapacks" 等）
        let relativePath: String
    }

    /// 识别资源文件（不复制）
    /// - Parameters:
    ///   - file: 资源文件路径
    ///   - relativePath: overrides 目录中的相对路径（如 "mods" / "datapacks" 等）
    /// - Returns: 处理结果
    static func identify(
        file: URL,
        relativePath: String
    ) async -> ProcessResult {
        // 尝试从 Modrinth 获取信息（同时拿到预计算的文件 hash）
        var indexFile: ModrinthIndexFile?
        if let modrinthResult = await ModrinthResourceIdentifier.getModrinthInfo(for: file) {
            // 找到 Modrinth 项目，尝试创建索引文件
            indexFile = await createIndexFile(
                from: file,
                fileHash: modrinthResult.fileHash,
                modrinthInfo: modrinthResult.info,
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

        // 如果索引文件创建失败（Modrinth 识别不到、创建失败等），需要复制到 overrides
        return ProcessResult(
            indexFile: nil,
            shouldCopyToOverrides: true,
            sourceFile: file,
            relativePath: relativePath
        )
    }

    /// 复制文件到 overrides 目录
    /// - Parameters:
    ///   - file: 源文件路径
    ///   - relativePath: overrides 目录中的相对路径（如 "mods" / "datapacks" 等）
    ///   - overridesDir: overrides 目录
    /// - Throws: 如果复制文件失败
    static func copyToOverrides(
        file: URL,
        relativePath: String,
        overridesDir: URL
    ) throws {
        let overridesSubDir = overridesDir.appendingPathComponent(relativePath)
        let destPath = overridesSubDir.appendingPathComponent(file.lastPathComponent)

        try FileManager.default.createDirectory(at: overridesSubDir, withIntermediateDirectories: true)

        // 如果目标文件已存在，先删除
        if FileManager.default.fileExists(atPath: destPath.path) {
            try? FileManager.default.removeItem(at: destPath)
        }

        try FileManager.default.copyItem(at: file, to: destPath)
    }

    /// 创建索引文件
    private static func createIndexFile(
        from modFile: URL,
        fileHash: String,
        modrinthInfo: ModrinthResourceIdentifier.ModrinthModInfo,
        relativePath: String
    ) async -> ModrinthIndexFile? {
        // 找到匹配的文件
        let matchingFile = modrinthInfo.version.files.first { file in
            file.hashes.sha1 == fileHash
        } ?? modrinthInfo.version.files.first

        guard let matchingFile = matchingFile else {
            return nil
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: modFile.path)[.size] as? Int64) ?? 0

        // 设置 env 字段（根据 Modrinth 项目的 clientSide 和 serverSide）
        // 将 Modrinth 的 "optional" 映射为 "optional"，其他值映射为 "required"
        let clientEnv = modrinthInfo.projectDetail.clientSide == "optional" ? "optional" : "required"
        let serverEnv = modrinthInfo.projectDetail.serverSide == "optional" ? "optional" : "required"

        let env = ModrinthIndexFileEnv(client: clientEnv, server: serverEnv)

        let indexPath: String
        if relativePath.isEmpty {
            indexPath = modFile.lastPathComponent
        } else {
            indexPath = "\(relativePath)/\(modFile.lastPathComponent)"
        }

        return ModrinthIndexFile(
            path: indexPath,
            hashes: ModrinthIndexFileHashes(from: [
                "sha1": matchingFile.hashes.sha1,
                "sha512": matchingFile.hashes.sha512,
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

    struct ModrinthLookupResult {
        let info: ModrinthModInfo
        let fileHash: String
    }

    private static let infoCache = ModrinthInfoCache()

    /// 始终通过 hash 查询 API，并在进程内缓存结果
    /// 同时返回用于匹配文件的本地 hash，避免重复计算
    static func getModrinthInfo(for modFile: URL) async -> ModrinthLookupResult? {
        guard let hash = try? SHA1Calculator.sha1(ofFileAt: modFile) else {
            return nil
        }

        // 先查本地缓存，避免对同一文件重复访问网络
        if let cached = await infoCache.get(hash: hash) {
            return ModrinthLookupResult(info: cached, fileHash: hash)
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
                            let info = ModrinthModInfo(
                                projectDetail: detail,
                                version: matchingVersion
                            )
                            await infoCache.set(info: info, for: hash)
                            continuation.resume(
                                returning: ModrinthLookupResult(
                                    info: info,
                                    fileHash: hash
                                )
                            )
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

/// Modrinth 信息进程级缓存（按文件 hash 缓存）
private actor ModrinthInfoCache {
    private var cache: [String: ModrinthResourceIdentifier.ModrinthModInfo] = [:]

    func get(hash: String) -> ModrinthResourceIdentifier.ModrinthModInfo? {
        return cache[hash]
    }

    func set(info: ModrinthResourceIdentifier.ModrinthModInfo, for hash: String) {
        cache[hash] = info
    }
}
