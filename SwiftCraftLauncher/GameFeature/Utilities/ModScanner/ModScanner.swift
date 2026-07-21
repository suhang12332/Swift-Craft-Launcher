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
    init() { }

    /// Schedules an asynchronous rebuild of directory hashes.
    nonisolated func scheduleDirectoryHashRebuild(
        standardizedDirectoryURL: URL,
        gameNameHint: String?,
    ) {
        Task.detached(priority: .utility) { [modScanner = self] in
            do {
                _ = try await modScanner.rebuildDirectoryHashes(
                    dir: standardizedDirectoryURL,
                    gameNameHint: gameNameHint,
                )
            } catch {
                let globalError = GlobalError.from(error)
                if let gameNameHint {
                    AppLog.game.error(
                        "FSEvents rescan of game \(gameNameHint) mods directory failed: \(globalError.localizedDescription)",
                    )
                } else {
                    AppLog.game.error(
                        "FSEvents rescan of directory \(standardizedDirectoryURL.lastPathComponent) failed: \(globalError.localizedDescription)",
                    )
                }
            }
        }
    }

    /// Retrieves a Modrinth project detail for the given file, returning the result via a completion handler.
    func getModrinthProjectDetail(
        for fileURL: URL,
        completion: @escaping (ModrinthProjectDetail?) -> Void,
    ) {
        Task {
            do {
                let detail = try await getModrinthProjectDetailThrowing(
                    for: fileURL,
                )
                completion(detail)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error(
                    "Failed to get Modrinth project details: \(globalError.localizedDescription)",
                )
                DIContainer.shared.core.errorHandler.handle(globalError)
                completion(nil)
            }
        }
    }

    /// Retrieves a Modrinth project detail for the given file.
    func getModrinthProjectDetailThrowing(
        for fileURL: URL,
    ) async throws -> ModrinthProjectDetail? {
        guard let hash = try Self.sha1HashThrowing(of: fileURL) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.file_hash_calculation_failed",
                level: .silent,
                message: "SHA1 hash calculation returned nil for file: \(fileURL.path)",
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

        if var detail {
            detail.type = inferredType
            var detailWithFileName = detail
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        }

        let fingerprint = try CurseForgeFingerprint.fingerprint(fileAt: fileURL)
        if let cfAsModrinth = await CurseForgeService.fetchProjectDetailsAsModrinthByFingerprint(
            fingerprint: fingerprint,
        ) {
            var detailWithFileName = cfAsModrinth
            detailWithFileName.type = inferredType
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        }

        let fallbackDetail = createFallbackDetailFromFileName(
            fileURL: fileURL,
        )
        saveToCache(hash: hash, detail: fallbackDetail)
        return fallbackDetail
    }

    /// Returns a cached mod detail for the given hash, or `nil` if absent.
    func getModCacheFromDatabase(hash: String) -> ModrinthProjectDetail? {
        guard let jsonData = DIContainer.shared.core.modCacheManager.get(hash: hash) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ModrinthProjectDetail.self, from: jsonData)
        } catch {
            AppLog.game.error("Failed to decode mod cache: \(error.localizedDescription)")
            return nil
        }
    }

    /// Encodes and persists a mod detail to the local cache.
    func saveToCache(hash: String, detail: ModrinthProjectDetail) {
        do {
            let jsonData = try JSONEncoder().encode(detail)
            DIContainer.shared.core.modCacheManager.setSilently(hash: hash, jsonData: jsonData)
        } catch {
            AppLog.game.error("Failed to encode mod cache: \(error.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(GlobalError.validation(
                i18nKey: "error.validation.mod_cache_encode_failed",
                level: .silent,
                message: "failed to encode mod cache for hash: \(hash)",
            ))
        }
    }

    /// Computes the SHA-1 hash of the file at the given URL, returning `nil` on failure.
    static func sha1Hash(of url: URL) -> String? {
        SHA1Calculator.sha1Silent(ofFileAt: url)
    }

    /// Computes the SHA-1 hash of the file at the given URL, throwing on I/O errors.
    static func sha1HashThrowing(of url: URL) throws -> String? {
        try SHA1Calculator.sha1(ofFileAt: url)
    }

    func sha1Hash(of url: URL) -> String? {
        Self.sha1Hash(of: url)
    }

    func sha1HashThrowing(of url: URL) throws -> String? {
        try Self.sha1HashThrowing(of: url)
    }
}
