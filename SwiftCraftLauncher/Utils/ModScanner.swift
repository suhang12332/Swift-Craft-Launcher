import Foundation
import CryptoKit

class ModScanner {
    static let shared = ModScanner()
    private init() {}
    
    /// 主入口：获取 ModrinthProjectDetail（静默版本）
    func getModrinthProjectDetail(for fileURL: URL, completion: @escaping (ModrinthProjectDetail?) -> Void) {
        Task {
            do {
                let detail = try await getModrinthProjectDetailThrowing(for: fileURL)
                completion(detail)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("获取 Modrinth 项目详情失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion(nil)
            }
        }
    }
    
    /// 主入口：获取 ModrinthProjectDetail（抛出异常版本）
    func getModrinthProjectDetailThrowing(for fileURL: URL) async throws -> ModrinthProjectDetail? {
        guard let hash = try Self.sha1HashThrowing(of: fileURL) else {
            throw GlobalError.validation(
                chineseMessage: "无法计算文件哈希值",
                i18nKey: "error.validation.file_hash_calculation_failed",
                level: .silent
            )
        }
        
        if let cached = AppCacheManager.shared.get(namespace: "mod", key: hash, as: ModrinthProjectDetail.self) {
            return cached
        }
        
        // 使用 fetchModrinthDetail 通过文件 hash 查询
        let detail = await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                continuation.resume(returning: detail)
            }
        }
        
        if let detail = detail {
            saveToCache(hash: hash, detail: detail)
            return detail
        } else {
            // 尝试本地解析
            let (modid, version) = try ModMetadataParser.parseModMetadataThrowing(fileURL: fileURL)
            if let modid = modid, let version = version {
                // 使用解析到的元数据创建兜底对象
                let fallbackDetail = createFallbackDetail(fileURL: fileURL, modid: modid, version: version)
                saveToCache(hash: hash, detail: fallbackDetail)
                return fallbackDetail
            } else {
                // 最终兜底策略：使用文件名创建基础信息
                let fallbackDetail = createFallbackDetailFromFileName(fileURL: fileURL)
                saveToCache(hash: hash, detail: fallbackDetail)
                return fallbackDetail
            }
        }
    }
    
    // 新增：外部调用缓存写入
    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        AppCacheManager.shared.setSilently(namespace: "mod", key: hash, value: detail)
    }

    // MARK: - Hash
    
    /// 计算文件 SHA1 哈希值（静默版本）
    static func sha1Hash(of url: URL) -> String? {
        return SHA1Calculator.sha1Silent(ofFileAt: url)
    }
    
    /// 计算文件 SHA1 哈希值（抛出异常版本）
    static func sha1HashThrowing(of url: URL) throws -> String? {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }
    
    // MARK: - Fallback Methods
    
    /// 使用解析到的元数据创建兜底 ModrinthProjectDetail
    private func createFallbackDetail(fileURL: URL, modid: String, version: String) -> ModrinthProjectDetail {
        let fileName = fileURL.lastPathComponent
        let baseFileName = fileName.replacingOccurrences(of: ".\(fileURL.pathExtension)", with: "")
        
        return ModrinthProjectDetail(
            slug: modid,
            title: baseFileName, // 使用去除扩展名的文件名作为标题
            description: "local：\(fileName)",
            categories: ["unknown"],
            clientSide: "optional",
            serverSide: "optional",
            body: "",
            status: "approved",
            requestedStatus: nil,
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            donationUrls: nil,
            projectType: "mod",
            downloads: 0,
            iconUrl: nil,
            color: nil,
            threadId: nil,
            monetizationStatus: nil,
            id: "local_\(modid)_\(UUID().uuidString.prefix(8))", // 生成唯一ID
            team: "local",
            bodyUrl: nil,
            moderatorMessage: nil,
            published: Date(),
            updated: Date(),
            approved: Date(),
            queued: nil,
            followers: 0,
            license: nil,
            versions: [version],
            gameVersions: [],
            loaders: [],
            gallery: nil,
            type: nil,
            fileName: fileName
        )
    }
    
    /// 使用文件名创建最基础的兜底 ModrinthProjectDetail
    private func createFallbackDetailFromFileName(fileURL: URL) -> ModrinthProjectDetail {
        let fileName = fileURL.lastPathComponent
        let baseFileName = fileName.replacingOccurrences(of: ".\(fileURL.pathExtension)", with: "")
        
        return ModrinthProjectDetail(
            slug: baseFileName.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: baseFileName, // 使用去除扩展名的文件名作为标题
            description: "local：\(fileName)",
            categories: ["unknown"],
            clientSide: "optional",
            serverSide: "optional",
            body: "",
            status: "approved",
            requestedStatus: nil,
            additionalCategories: nil,
            issuesUrl: nil,
            sourceUrl: nil,
            wikiUrl: nil,
            discordUrl: nil,
            donationUrls: nil,
            projectType: "mod",
            downloads: 0,
            iconUrl: nil,
            color: nil,
            threadId: nil,
            monetizationStatus: nil,
            id: "file_\(baseFileName)_\(UUID().uuidString.prefix(8))", // 生成唯一ID
            team: "local",
            bodyUrl: nil,
            moderatorMessage: nil,
            published: Date(),
            updated: Date(),
            approved: Date(),
            queued: nil,
            followers: 0,
            license: nil,
            versions: ["unknown"],
            gameVersions: [],
            loaders: [],
            gallery: nil,
            type: nil,
            fileName: fileName
        )
    }
}

extension ModScanner {
    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（静默版本）
    public func localModDetails(in dir: URL) -> [(file: URL, hash: String, detail: ModrinthProjectDetail?)] {
        do {
            return try localModDetailsThrowing(in: dir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取本地 mod 详情失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return []
        }
    }
    
    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（抛出异常版本）
    public func localModDetailsThrowing(in dir: URL) throws -> [(file: URL, hash: String, detail: ModrinthProjectDetail?)] {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw GlobalError.resource(
                chineseMessage: "目录不存在: \(dir.lastPathComponent)",
                i18nKey: "error.resource.directory_not_found",
                level: .silent
            )
        }
        
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "读取目录失败: \(dir.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent
            )
        }
        
        let jarFiles = files.filter { ["jar", "zip"].contains($0.pathExtension.lowercased()) }
        return jarFiles.compactMap { fileURL in
            if let hash = ModScanner.sha1Hash(of: fileURL) {
                var detail = AppCacheManager.shared.get(namespace: "mod", key: hash, as: ModrinthProjectDetail.self)
                
                // 如果缓存中没有找到，使用兜底策略创建基础信息
                if detail == nil {
                    detail = createFallbackDetailFromFileName(fileURL: fileURL)
                    // 保存兜底信息到缓存，避免重复创建
                    saveToCache(hash: hash, detail: detail!)
                }
                
                return (file: fileURL, hash: hash, detail: detail)
            }
            return nil
        }
    }

    /// 同步：仅查缓存
    func isModInstalledSync(projectId: String, in modsDir: URL) -> Bool {
        do {
            return try isModInstalledSyncThrowing(projectId: projectId, in: modsDir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查 mod 安装状态失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }
    
    /// 同步：仅查缓存（抛出异常版本）
    func isModInstalledSyncThrowing(projectId: String, in modsDir: URL) throws -> Bool {
        for (_, _, detail) in try localModDetailsThrowing(in: modsDir) {
            if let detail = detail, detail.id == projectId {
                return true
            }
        }
        return false
    }

    /// 异步：查缓存+API+本地解析（静默版本）
    func isModInstalled(projectId: String, in modsDir: URL, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let result = try await isModInstalledThrowing(projectId: projectId, in: modsDir)
                completion(result)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("检查 mod 安装状态失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion(false)
            }
        }
    }
    
    /// 异步：查缓存+API+本地解析（抛出异常版本）
    func isModInstalledThrowing(projectId: String, in modsDir: URL) async throws -> Bool {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: nil)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "读取目录失败: \(modsDir.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent
            )
        }
        
        let jarFiles = files.filter { ["jar", "zip"].contains($0.pathExtension.lowercased()) }
        if jarFiles.isEmpty {
            return false
        }
        
        for fileURL in jarFiles {
            if let detail = try await getModrinthProjectDetailThrowing(for: fileURL),
               detail.id == projectId {
                return true
            }
        }
        return false
    }

    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（静默版本）
    func scanResourceDirectory(_ dir: URL, completion: @escaping ([ModrinthProjectDetail]) -> Void) {
        Task {
            do {
                let results = try await scanResourceDirectoryThrowing(dir)
                completion(results)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描资源目录失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                completion([])
            }
        }
    }
    
    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（抛出异常版本）
    func scanResourceDirectoryThrowing(_ dir: URL) async throws -> [ModrinthProjectDetail] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "读取目录失败: \(dir.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.directory_read_failed",
                level: .silent
            )
        }
        
        let jarFiles = files.filter { ["jar", "zip"].contains($0.pathExtension.lowercased()) }
        if jarFiles.isEmpty {
            return []
        }
        
        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(value: 4)
        
        // 使用 TaskGroup 并发扫描文件
        let results = await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
            for fileURL in jarFiles {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    return try? await self.getModrinthProjectDetailThrowing(for: fileURL)
                }
            }
            
            // 收集结果
            var results: [ModrinthProjectDetail] = []
            for await result in group {
                if let detail = result {
                    results.append(detail)
                }
            }
            return results
        }
        
        return results
    }
}
