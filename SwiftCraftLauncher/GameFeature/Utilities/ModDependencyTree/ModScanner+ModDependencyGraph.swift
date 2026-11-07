//
//  ModScanner+ModDependencyGraph.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModScanner {
    /// Retrieves the project detail and returns the computed hash for callers
    /// that need to resolve the installed version as well.
    func getModrinthProjectDetailWithHash(
        for fileURL: URL,
    ) async throws -> (project: ModrinthProjectDetail, hash: String)? {
        guard let hash = try await Self.sha1HashThrowing(of: fileURL) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.file_hash_calculation_failed",
                level: .silent,
                message: "SHA1 hash calculation returned nil for file: \(fileURL.path)",
            )
        }
        guard let project = try await getModrinthProjectDetail(for: fileURL, hash: hash) else {
            return nil
        }
        return (project, hash)
    }

    /// Resolves project details using a hash that has already been calculated.
    func getModrinthProjectDetail(
        for fileURL: URL,
        hash: String,
    ) async throws -> ModrinthProjectDetail? {
        let inferredType = AppPaths.resourceType(for: fileURL)
        if let cached = getModCacheFromDatabase(hash: hash) {
            var updatedCached = cached
            updatedCached.fileName = fileURL.lastPathComponent
            return updatedCached
        }

        let detail = try? await ModrinthService.fetchModrinthDetailThrowing(by: hash)

        if var detail {
            detail.type = inferredType
            var detailWithFileName = detail
            detailWithFileName.fileName = fileURL.lastPathComponent
            saveToCache(hash: hash, detail: detailWithFileName)
            return detailWithFileName
        }

        let fingerprint = try CurseForgeFingerprint.fingerprint(fileAt: fileURL)
        if let cfAsModrinth = try? await CurseForgeService.fetchProjectDetailsAsModrinthByFingerprintThrowing(
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
}
