//
//  ModPackDependencyInstaller+Files.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

extension ModPackDependencyInstaller {
    /// Downloads and installs all modpack files that are not excluded by environment constraints.
    static func installModPackFiles(
        files: [ModrinthIndexFile],
        resourceDir: URL,
        gameInfo: GameVersionInfo,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?,
    ) async -> Bool {
        let filesToDownload = filterDownloadableFiles(files)

        onProgressUpdate?("modpack.progress.files_download_started".localized(), 0, filesToDownload.count, .files)

        let semaphore = AsyncSemaphore(value: downloadSemaphoreValue)
        let completedCount = ModPackCounter()

        let results = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, file) in filesToDownload.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    let success = await downloadSingleFile(file: file, resourceDir: resourceDir, gameInfo: gameInfo)

                    if success {
                        let currentCount = completedCount.increment()
                        onProgressUpdate?(file.path, currentCount, filesToDownload.count, .files)
                    }

                    return (index, success)
                }
            }

            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }
        }

        let successCount = results.count { $0.1 }
        let failedCount = results.count - successCount

        if failedCount > 0 {
            AppLog.modPack.error("\(failedCount) files failed to download")
            return false
        }

        onProgressUpdate?("modpack.progress.files_download_completed".localized(), filesToDownload.count, filesToDownload.count, .files)

        return true
    }

    private static func filterDownloadableFiles(_ files: [ModrinthIndexFile]) -> [ModrinthIndexFile] {
        files.filter { file in
            if let env = file.env, let client = env.client, client.lowercased() == "unsupported" {
                return false
            }
            return true
        }
    }

    private static func downloadSingleFile(
        file: ModrinthIndexFile,
        resourceDir: URL,
        gameInfo: GameVersionInfo? = nil,
    ) async -> Bool {
        if file.source == .curseforge,
           let projectId = file.curseForgeProjectId,
           let fileId = file.curseForgeFileId {
            return await downloadCurseForgeFile(
                projectId: projectId,
                fileId: fileId,
                resourceDir: resourceDir,
                gameInfo: gameInfo,
            )
        }
        return await downloadModrinthFile(file: file, resourceDir: resourceDir)
    }

    private static func downloadCurseForgeFile(
        projectId: Int,
        fileId: Int,
        resourceDir: URL,
        gameInfo _: GameVersionInfo? = nil,
    ) async -> Bool {
        let fileDetail = await CurseForgeService.fetchFileDetail(projectId: projectId, fileId: fileId)

        if let fileDetail {
            if await downloadCurseForgeFileWithDetail(
                fileDetail: fileDetail,
                projectId: projectId,
                resourceDir: resourceDir,
            ) {
                return true
            }
        }
        return false
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

            let downloadedFile = try await DownloadManager.downloadFile(
                urlString: downloadUrl,
                destinationURL: destinationPath,
                expectedSha1: fileDetail.hash?.value,
            )

            if let hash = DIContainer.shared.core.modScanner.sha1Hash(of: downloadedFile) {
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

        let destinationPath = autoreleasepool {
            resourceDir.appendingPathComponent(file.path)
        }

        let downloadedFile: URL
        do {
            downloadedFile = try await DownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationPath,
                expectedSha1: file.hashes["sha1"],
            )
        } catch {
            AppLog.modPack.error("Failed to download file: \(file.path)")
            return false
        }

        if let hash = DIContainer.shared.core.modScanner.sha1Hash(of: downloadedFile),
           var detailWithFile = try? await ModrinthService.fetchModrinthDetailThrowing(by: hash) {
            let fileUrl = URL(fileURLWithPath: file.path)
            detailWithFile.fileName = fileUrl.lastPathComponent
            detailWithFile.type = AppPaths.resourceType(for: fileUrl)
            DIContainer.shared.core.modScanner.saveToCache(hash: hash, detail: detailWithFile)
        }
        return true
    }
}
