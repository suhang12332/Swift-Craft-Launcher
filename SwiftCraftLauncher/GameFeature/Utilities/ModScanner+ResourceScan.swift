import Foundation

extension ModScanner {
    // MARK: - 资源目录扫描

    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（静默版本）
    func scanResourceDirectory(
        _ dir: URL,
        completion: @escaping ([ModrinthProjectDetail]) -> Void
    ) {
        Task {
            do {
                let results = try await scanResourceDirectoryThrowing(dir)
                completion(results)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("扫描资源目录失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
                completion([])
            }
        }
    }

    /// 扫描目录，返回所有已识别的 ModrinthProjectDetail（抛出异常版本）
    func scanResourceDirectoryThrowing(
        _ dir: URL
    ) async throws -> [ModrinthProjectDetail] {
        // 复用本地详情扫描逻辑，只返回非空 detail
        let items = try scanDirectoryForDetails(in: dir)
        return items.compactMap { $0.detail }
    }

    // MARK: - 分页扫描

    /// 计算分页范围
    func calculatePageRange(
        totalCount: Int,
        page: Int,
        pageSize: Int
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

    /// 并发扫描文件列表并返回详情
    func scanFilesConcurrently(
        fileURLs: [URL],
        semaphore: AsyncSemaphore
    ) async -> [ModrinthProjectDetail] {
        await withTaskGroup(of: ModrinthProjectDetail?.self) { group in
            for fileURL in fileURLs {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    return try? await self.getModrinthProjectDetailThrowing(
                        for: fileURL
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

    /// 扫描目录下所有 jar/zip 文件，返回文件 URL + hash + 详情（若无缓存则使用兜底 detail）
    func scanDirectoryForDetails(
        in dir: URL
    ) throws -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        let jarFiles = try readJarZipFiles(from: dir)
        return jarFiles.compactMap { fileURL in
            guard let hash = sha1Hash(of: fileURL) else {
                return nil
            }

            var detail = getModCacheFromDatabase(hash: hash)

            // 如果缓存中没有找到，使用兜底策略创建基础信息
            if detail == nil {
                detail = createFallbackDetailFromFileName(fileURL: fileURL)
                // 保存兜底信息到缓存，避免重复创建
                if let detail = detail {
                    saveToCache(hash: hash, detail: detail)
                }
            } else {
                // 更新文件名为当前实际文件名（可能已重命名为 .disabled）
                detail?.fileName = fileURL.lastPathComponent
            }

            return (file: fileURL, hash: hash, detail: detail)
        }
    }

    /// 获取目录下所有 jar/zip 文件列表（不解析详情，快速）
    func getAllResourceFiles(_ dir: URL) -> [URL] {
        do {
            return try getAllResourceFilesThrowing(dir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取资源文件列表失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return []
        }
    }

    /// 获取目录下所有 jar/zip 文件列表（抛出异常版本）
    func getAllResourceFilesThrowing(_ dir: URL) throws -> [URL] {
        // 目录不存在时返回空数组（不抛出异常，因为这是正常情况）
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }

        return try readJarZipFiles(from: dir)
    }

    /// 分页扫描目录，仅对当前页的文件进行解析（静默版本）
    func scanResourceDirectoryPage(
        _ dir: URL,
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceDirectoryPageThrowing(
                    dir,
                    page: page,
                    pageSize: pageSize
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("分页扫描资源目录失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
                completion([], false)
            }
        }
    }

    /// 基于文件列表分页扫描，仅对当前页的文件进行解析（静默版本）
    func scanResourceFilesPage(
        fileURLs: [URL],
        page: Int,
        pageSize: Int,
        completion: @escaping ([ModrinthProjectDetail], Bool) -> Void
    ) {
        Task {
            do {
                let (results, hasMore) = try await scanResourceFilesPageThrowing(
                    fileURLs: fileURLs,
                    page: page,
                    pageSize: pageSize
                )
                completion(results, hasMore)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error("分页扫描资源文件失败: \(globalError.chineseMessage)")
                errorHandler.handle(globalError)
                completion([], false)
            }
        }
    }

    /// 基于文件列表分页扫描，仅对当前页的文件进行解析（抛出异常版本）
    func scanResourceFilesPageThrowing(
        fileURLs: [URL],
        page: Int,
        pageSize: Int
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        guard let pageRange = calculatePageRange(
            totalCount: fileURLs.count,
            page: page,
            pageSize: pageSize
        ) else {
            return ([], false)
        }

        let pageFiles = Array(fileURLs[pageRange.startIndex..<pageRange.endIndex])
        let concurrentCount = AppServices.generalSettingsManager.concurrentDownloads
        let semaphore = AsyncSemaphore(value: concurrentCount)
        let results = await scanFilesConcurrently(fileURLs: pageFiles, semaphore: semaphore)

        return (results, pageRange.hasMore)
    }

    /// 分页扫描目录，仅对当前页的文件进行解析（抛出异常版本）
    func scanResourceDirectoryPageThrowing(
        _ dir: URL,
        page: Int,
        pageSize: Int
    ) async throws -> ([ModrinthProjectDetail], Bool) {
        let jarFiles = try readJarZipFiles(from: dir)
        return try await scanResourceFilesPageThrowing(
            fileURLs: jarFiles,
            page: page,
            pageSize: pageSize
        )
    }
}
