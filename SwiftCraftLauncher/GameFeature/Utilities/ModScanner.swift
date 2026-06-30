//
//  ModScanner.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CryptoKit
import Foundation

/// Scans mod and resource files, resolving details from Modrinth and CurseForge.
class ModScanner {
    static let shared = ModScanner()
    let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    /// Schedules an asynchronous rebuild of directory hashes.
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

    /// Retrieves a Modrinth project detail for the given file, returning the result via a completion handler.
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

    /// Retrieves a Modrinth project detail for the given file.
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
            var updatedCached = cached
            updatedCached.fileName = fileURL.lastPathComponent
            return updatedCached
        }

        let detail = await withCheckedContinuation { continuation in
            ModrinthService.fetchModrinthDetail(by: hash) { detail in
                continuation.resume(returning: detail)
            }
        }

        if var detail = detail {
            detail.type = inferredType
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

    /// Returns a cached mod detail for the given hash, or `nil` if absent.
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

    /// Encodes and persists a mod detail to the local cache.
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

    /// Computes the SHA-1 hash of the file at the given URL, returning `nil` on failure.
    static func sha1Hash(of url: URL) -> String? {
        return SHA1Calculator.sha1Silent(ofFileAt: url)
    }

    /// Computes the SHA-1 hash of the file at the given URL, throwing on I/O errors.
    static func sha1HashThrowing(of url: URL) throws -> String? {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }

    func sha1Hash(of url: URL) -> String? {
        Self.sha1Hash(of: url)
    }

    func sha1HashThrowing(of url: URL) throws -> String? {
        try Self.sha1HashThrowing(of: url)
    }
}
