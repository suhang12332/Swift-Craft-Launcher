import CryptoKit
import Foundation

/// Mod / 资源文件扫描与 Modrinth 详情解析
class ModScanner {
    static let shared = ModScanner()
    let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    nonisolated func scheduleDirectoryHashRebuild(
        standardizedDirectoryURL: URL,
        gameNameHint: String?
    ) {
        Task.detached(priority: .utility) { [modScanner = self] in
            do {
                _ = try await modScanner.rebuildDirectoryHashes(
                    dir: standardizedDirectoryURL,
                    gameNameHint: gameNameHint
                )
            } catch {
                let globalError = GlobalError.from(error)
                if let gameNameHint {
                    Logger.shared.warning(
                        "FSEvents 重新扫描游戏 \(gameNameHint) 的 mods 目录失败: \(globalError.chineseMessage)"
                    )
                } else {
                    Logger.shared.warning(
                        "FSEvents 重新扫描目录 \(standardizedDirectoryURL.lastPathComponent) 失败: \(globalError.chineseMessage)"
                    )
                }
            }
        }
    }

    /// 主入口：获取 ModrinthProjectDetail（静默版本）
    func getModrinthProjectDetail(
        for fileURL: URL,
        completion: @escaping (ModrinthProjectDetail?) -> Void
    ) {
        Task {
            do {
                let detail = try await getModrinthProjectDetailThrowing(
                    for: fileURL
                )
                completion(detail)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(
                    "获取 Modrinth 项目详情失败: \(globalError.chineseMessage)"
                )
                errorHandler.handle(globalError)
                completion(nil)
            }
        }
    }

    /// 主入口：获取 ModrinthProjectDetail（抛出异常版本）
    func getModrinthProjectDetailThrowing(
        for fileURL: URL
    ) async throws -> ModrinthProjectDetail? {
        guard let hash = try Self.sha1HashThrowing(of: fileURL) else {
            throw GlobalError.validation(
                chineseMessage: "无法计算文件哈希值",
                i18nKey: "error.validation.file_hash_calculation_failed",
                level: .silent
            )
        }

        let inferredType = AppPaths.resourceType(for: fileURL)
        if let cached = getModCacheFromDatabase(hash: hash) {
            // 更新文件名为当前实际文件名（可能已重命名为 .disabled）
            var updatedCached = cached
            updatedCached.fileName = fileURL.lastPathComponent
            return updatedCached
        }

        // 使用 fetchModrinthDetail 通过文件 hash 查询
        let detail = await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                continuation.resume(returning: detail)
            }
        }

        if var detail = detail {
            detail.type = inferredType
            // 设置本地文件名
            var detailWithFileName = detail
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        }

        let fingerprint = try CurseForgeFingerprint.fingerprint(fileAt: fileURL)
        if let cfAsModrinth = await CurseForgeService.fetchProjectDetailsAsModrinthByFingerprint(
            fingerprint: fingerprint
        ) {
            var detailWithFileName = cfAsModrinth
            detailWithFileName.type = inferredType
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        }

        let fallbackDetail = createFallbackDetailFromFileName(
            fileURL: fileURL
        )
        saveToCache(hash: hash, detail: fallbackDetail)
        return fallbackDetail
    }

    // MARK: - Mod Cache (Database)

    func getModCacheFromDatabase(hash: String) -> ModrinthProjectDetail? {
        guard let jsonData = AppServices.modCacheManager.get(hash: hash) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ModrinthProjectDetail.self, from: jsonData)
        } catch {
            Logger.shared.error("解码 mod 缓存失败: \(error.localizedDescription)")
            return nil
        }
    }

    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        do {
            let jsonData = try JSONEncoder().encode(detail)
            AppServices.modCacheManager.setSilently(hash: hash, jsonData: jsonData)
        } catch {
            Logger.shared.error("编码 mod 缓存失败: \(error.localizedDescription)")
            errorHandler.handle(GlobalError.validation(
                chineseMessage: "保存 mod 缓存失败: \(error.localizedDescription)",
                i18nKey: "error.validation.mod_cache_encode_failed",
                level: .silent
            ))
        }
    }

    // MARK: - Hash

    static func sha1Hash(of url: URL) -> String? {
        return SHA1Calculator.sha1Silent(ofFileAt: url)
    }

    static func sha1HashThrowing(of url: URL) throws -> String? {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }
}
