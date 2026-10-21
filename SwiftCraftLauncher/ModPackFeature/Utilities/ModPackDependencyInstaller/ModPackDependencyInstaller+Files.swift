//
//  ModPackDependencyInstaller+Files.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackDependencyInstaller {
    /// Downloads and installs all modpack files that are not excluded by environment constraints.
    /// - Returns: The files that failed to download (empty when all succeeded).
    static func installModPackFiles(
        files: [ModrinthIndexFile],
        resourceDir: URL,
        gameInfo _: GameVersionInfo,
        onProgressUpdate: (@Sendable (String, Int, Int, DownloadType) -> Void)?,
    ) async -> [ModrinthIndexFile] {
        let filesToDownload = filterDownloadableFiles(files)

        onProgressUpdate?("modpack.progress.files_download_started".localized(), 0, filesToDownload.count, .files)

        // Largest first. A big file that starts late becomes the tail of the whole
        // install, waiting on nothing else; starting it up front lets the small
        // files fill in around it and shortens the critical path.
        let downloadOrder = filesToDownload.indices.sorted {
            filesToDownload[$0].fileSize > filesToDownload[$1].fileSize
        }

        let semaphore = AsyncSemaphore(value: downloadSemaphoreValue)
        let completedCount = AtomicCounter()

        let results = await withTaskGroup(of: (Int, ModrinthIndexFile?).self) { group in
            for index in downloadOrder {
                // Stop queueing work once the install is cancelled: every task
                // already running will fail fast on its own, and adding more
                // only keeps the network busy after the user asked to stop.
                guard !Task.isCancelled else { break }
                let file = filesToDownload[index]
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    guard !Task.isCancelled else { return (index, file) }

                    let success = await downloadSingleFile(file: file, resourceDir: resourceDir)

                    if success {
                        let currentCount = await completedCount.increment()
                        onProgressUpdate?(file.path, currentCount, filesToDownload.count, .files)
                        return (index, nil)
                    }

                    return (index, file)
                }
            }

            var results: [(Int, ModrinthIndexFile?)] = []
            for await result in group {
                results.append(result)
                if Task.isCancelled { group.cancelAll() }
            }
            return results.sorted { $0.0 < $1.0 }
        }

        let failedFiles = results.compactMap(\.1)

        if !failedFiles.isEmpty {
            AppLog.modPack.error("\(failedFiles.count) files failed to download")
            return failedFiles
        }

        onProgressUpdate?("modpack.progress.files_download_completed".localized(), filesToDownload.count, filesToDownload.count, .files)

        return []
    }

    private static func filterDownloadableFiles(_ files: [ModrinthIndexFile]) -> [ModrinthIndexFile] {
        files.filter { file in
            if let env = file.env, let client = env.client, client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
    }

    /// Whether a file of this size is worth offering to the chunked downloader.
    ///
    /// Chunking opens with a HEAD request to confirm the host serves ranges, so
    /// offering it to every mod would add one round trip per file for the many
    /// that are too small to be split anyway. The size is already known from the
    /// index, so small files skip the probe and go straight to a single stream.
    private static func allowsChunking(forFileSize size: Int?) -> Bool {
        guard let size else { return false }
        return ChunkedDownloadConfig.isWorthChunking(fileSize: Int64(size))
    }

    private static func downloadSingleFile(
        file: ModrinthIndexFile,
        resourceDir: URL,
    ) async -> Bool {
        if file.source == .curseforge,
           let projectId = file.curseForgeProjectId,
           let fileId = file.curseForgeFileId {
            return await downloadCurseForgeFile(
                projectId: projectId,
                fileId: fileId,
                resourceDir: resourceDir,
            )
        }
        return await downloadModrinthFile(file: file, resourceDir: resourceDir)
    }

    private static func downloadCurseForgeFile(
        projectId: Int,
        fileId: Int,
        resourceDir: URL,
    ) async -> Bool {
        guard let fileDetail = try? await CurseForgeService.fetchFileDetailThrowing(projectId: projectId, fileId: fileId) else {
            AppLog.modPack.error("Failed to fetch CurseForge file detail for project \(projectId), file \(fileId)")
            return false
        }

        return await downloadCurseForgeFileWithDetail(
            fileDetail: fileDetail,
            projectId: projectId,
            resourceDir: resourceDir,
        )
    }

    private static func downloadCurseForgeFileWithDetail(
        fileDetail: CurseForgeModFileDetail,
        projectId: Int,
        resourceDir: URL,
    ) async -> Bool {
        do {
            let downloadUrl: String
            if let directUrl = fileDetail.downloadUrl, !directUrl.isEmpty {
                downloadUrl = directUrl
            } else {
                downloadUrl = URLConfig.API.CurseForge.fallbackDownloadUrl(
                    fileId: fileDetail.id,
                    fileName: fileDetail.fileName,
                ).absoluteString
            }

            let effectiveModDetail = try await CurseForgeService.fetchModDetailThrowing(modId: projectId)
            let subDirectory = effectiveModDetail.directoryName
            let destinationPath = resourceDir
                .appendingPathComponent(subDirectory)
                .appendingPathComponent(fileDetail.fileName)

            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )

            // CurseForge stays on a single stream. Its CDN answers byte-range
            // requests from third-party clients with 403 and throttles bursts
            // hard, so the extra connections buy nothing and can fail the whole
            // install. Modrinth's CDN does serve ranges, so only that path opts in.
            let downloadedFile = try await DownloadManager.downloadFile(
                urlString: downloadUrl,
                destinationURL: destinationPath,
                expectedSha1: fileDetail.hash?.value,
                headers: CurseForgeService.getHeaders(),
            )

            if let hash = await DIContainer.shared.core.modScanner.sha1Hash(of: downloadedFile) {
                if let cfAsModrinth = CFToModrinthAdapter.convertProjectDetail(effectiveModDetail) {
                    var detailWithFile = cfAsModrinth
                    detailWithFile.fileName = fileDetail.fileName
                    detailWithFile.type = detailWithFile.projectType
                    DIContainer.shared.core.modScanner.saveToCache(hash: hash, detail: detailWithFile)
                }
            }

            return true
        } catch {
            AppLog.modPack.error("Failed to download CurseForge file: \(fileDetail.fileName)")
            return false
        }
    }

    private static func downloadModrinthFile(file: ModrinthIndexFile, resourceDir: URL) async -> Bool {
        guard let urlString = file.downloads.first, !urlString.isEmpty else {
            AppLog.modPack.error("File has no available download URL: \(file.path)")
            return false
        }

        let destinationPath = resourceDir.appendingPathComponent(file.path)

        let downloadedFile: URL
        do {
            downloadedFile = try await DownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationPath,
                expectedSha1: file.hashes["sha1"],
                allowsChunking: allowsChunking(forFileSize: file.fileSize),
            )
        } catch {
            AppLog.modPack.error("Failed to download file: \(file.path)")
            return false
        }

        if let hash = await DIContainer.shared.core.modScanner.sha1Hash(of: downloadedFile),
           var detailWithFile = try? await ModrinthService.fetchModrinthDetailThrowing(by: hash) {
            let fileUrl = URL(fileURLWithPath: file.path)
            detailWithFile.fileName = fileUrl.lastPathComponent
            detailWithFile.type = AppPaths.resourceType(for: fileUrl)
            DIContainer.shared.core.modScanner.saveToCache(hash: hash, detail: detailWithFile)
        }
        return true
    }
}
