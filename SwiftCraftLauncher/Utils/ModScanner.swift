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
        
        // 使用新的 ModrinthService API
        if let detail = await ModrinthService.fetchProjectDetails(id: hash) {
            saveToCache(hash: hash, detail: detail)
            return detail
        } else {
            // 尝试本地解析
            let (modid, version) = try ModMetadataParser.parseModMetadataThrowing(fileURL: fileURL)
            guard let _ = modid, let _ = version else {
                return nil // 无法识别的 mod
            }
            return nil // 如有后续逻辑可补充
        }
    }
    
    // 新增：外部调用缓存写入
    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        AppCacheManager.shared.setSilently(namespace: "mod", key: hash, value: detail)
    }

    // MARK: - Hash
    
    /// 计算文件 SHA1 哈希值（静默版本）
    static func sha1Hash(of url: URL) -> String? {
        do {
            return try sha1HashThrowing(of: url)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("计算文件哈希值失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }
    
    /// 计算文件 SHA1 哈希值（抛出异常版本）
    static func sha1HashThrowing(of url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw GlobalError.resource(
                chineseMessage: "文件不存在: \(url.lastPathComponent)",
                i18nKey: "error.resource.file_not_found",
                level: .silent
            )
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "读取文件失败: \(url.lastPathComponent), 错误: \(error.localizedDescription)",
                i18nKey: "error.filesystem.file_read_failed",
                level: .silent
            )
        }
        
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
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
                let detail = AppCacheManager.shared.get(namespace: "mod", key: hash, as: ModrinthProjectDetail.self)
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
        
        var results: [ModrinthProjectDetail] = []
        for fileURL in jarFiles {
            if let detail = try await getModrinthProjectDetailThrowing(for: fileURL) {
                results.append(detail)
            }
        }
        return results
    }
}
