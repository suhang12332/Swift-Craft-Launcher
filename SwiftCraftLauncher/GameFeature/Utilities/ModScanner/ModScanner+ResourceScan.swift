//
//  ModScanner+ResourceScan.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Resource directory scanning with support for paginated and concurrent detail resolution.
extension ModScanner {
    /// Scans a resource directory and returns all recognized `ModrinthProjectDetail` instances.
    func scanResourceDirectory(
        _ dir: URL,
        completion: @escaping ([ModrinthProjectDetail]) -> Void,
    ) {
        Task {
            do {
                let results = try await scanResourceDirectoryThrowing(dir)
                completion(results)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error("Failed to scan resource directory: \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
                completion([])
            }
        }
    }

    /// Scans a resource directory and returns all recognized `ModrinthProjectDetail` instances.
    func scanResourceDirectoryThrowing(
        _ dir: URL,
    ) async throws -> [ModrinthProjectDetail] {
        let items = try scanDirectoryForDetails(in: dir)
        return items.compactMap(\.detail)
    }

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
        await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    return try? await self.getModrinthProjectDetailThrowing(
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
    }

    /// Scans all jar and zip files in the directory, returning each file's URL, hash, and resolved detail.
    func scanDirectoryForDetails(
        in dir: URL,
    ) throws -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        let jarFiles = try readJarZipFiles(from: dir)
        return jarFiles.compactMap { fileURL in
            guard let hash = sha1Hash(of: fileURL) else {
                return nil
            }

            var detail = getModCacheFromDatabase(hash: hash)

            if detail == nil {
                detail = createFallbackDetailFromFileName(fileURL: fileURL)
                if let detail {
                    saveToCache(hash: hash, detail: detail)
                }
            } else {
                detail?.fileName = fileURL.lastPathComponent
            }

            return (file: fileURL, hash: hash, detail: detail)
        }
    }

    /// Returns all jar and zip files in the directory without resolving details.
    func getAllResourceFiles(_ dir: URL) -> [URL] {
        do {
            return try getAllResourceFilesThrowing(dir)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to get resource file list: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
            return []
        }
    }

    /// Returns all jar and zip files in the directory without resolving details, returning an empty array if the directory does not exist.
    func getAllResourceFilesThrowing(_ dir: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }

        return try readJarZipFiles(from: dir)
    }

    /// Scans a resource directory by page, resolving details only for the requested page.
    func scanResourceDirectoryPage(
        _ dir: URL,
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void,
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceDirectoryPageThrowing(
                    dir,
                    page: page,
                    pageSize: pageSize,
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error("Failed to scan resource directory (paged): \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
                completion([], false)
            }
        }
    }

    /// Scans a list of files by page, resolving details only for the requested page.
    func scanResourceFilesPage(
        fileURLs: [URL],
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void,
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceFilesPageThrowing(
                    fileURLs: fileURLs,
                    page: page,
                    pageSize: pageSize,
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error("Failed to scan resource files (paged): \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
                completion([], false)
            }
        }
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
        let concurrentCount = DIContainer.shared.ui.generalSettingsManager.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)
        let results = await scanFilesConcurrently(fileURLs: pageFiles, semaphore: semaphore)

        return (results, pageRange.hasMore)
    }

    /// Scans a resource directory by page, resolving details only for the requested page.
    func scanResourceDirectoryPageThrowing(
        _ dir: URL,
        page: Int,
        pageSize: Int,
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        let jarFiles = try readJarZipFiles(from: dir)
        return try await scanResourceFilesPageThrowing(
            fileURLs: jarFiles,
            page: page,
            pageSize: pageSize,
        )
    }
}
