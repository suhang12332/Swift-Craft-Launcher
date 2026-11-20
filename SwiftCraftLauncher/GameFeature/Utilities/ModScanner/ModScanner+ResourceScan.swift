//
//  ModScanner+ResourceScan.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Resource directory scanning with support for paginated and concurrent detail resolution.
extension ModScanner {
    /// Calculates the start index, end index, and whether more pages remain for the given pagination parameters.
    func calculatePageRange(
        totalCount: Int,
        page: Int,
        pageSize: Int,
    ) -> (startIndex: Int, endIndex: Int, hasMore: Bool)? {
        guard totalCount > 0 else {
            return nil
        }

        let safePage = max(page, 1)
        let safePageSize = max(pageSize, 1)
        let startIndex = (safePage - 1) * safePageSize
        let endIndex = min(startIndex + safePageSize, totalCount)

        guard startIndex < totalCount else {
            return nil
        }

        return (startIndex, endIndex, endIndex < totalCount)
    }

    /// Concurrently scans a list of file URLs and returns their resolved details.
    func scanFilesConcurrently(
        fileURLs: [URL],
        semaphore: AsyncSemaphore,
    ) async -> [ModrinthProjectDetail] {
        await Task.detached { [modScanner = self] in
            await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
                for fileURL in fileURLs {
                    group.addTask {
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }

                        return try? await modScanner.getModrinthProjectDetail(
                            for: fileURL,
                        )
                    }
                }

                var results: [ModrinthProjectDetail] = []
                for await result in group {
                    if let detail = result {
                        results.append(detail)
                    }
                }
                return results
            }
        }.value
    }

    /// Returns all jar and zip files in the directory without resolving details.
    ///
    /// Uses the shared directory-listing cache, so the Game Overview and local
    /// resource list reuse the same scan. The cache refreshes automatically when
    /// the directory modification date changes.
    /// Returns an empty array when the directory does not exist.
    func getAllResourceFilesThrowing(_ dir: URL) throws -> [URL] {
        try resourceFileCache.archiveFiles(in: dir)
    }

    /// Scans a list of files by page, resolving details only for the requested page.
    func scanResourceFilesPageThrowing(
        fileURLs: [URL],
        page: Int,
        pageSize: Int,
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        guard let pageRange = calculatePageRange(
            totalCount: fileURLs.count,
            page: page,
            pageSize: pageSize,
        ) else {
            return ([], false)
        }

        let pageFiles = Array(fileURLs[pageRange.startIndex ..< pageRange.endIndex])
        let concurrentCount = DIContainer.shared.ui.gameSettingsManager.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)
        let results = await scanFilesConcurrently(fileURLs: pageFiles, semaphore: semaphore)

        return (results, pageRange.hasMore)
    }
}
