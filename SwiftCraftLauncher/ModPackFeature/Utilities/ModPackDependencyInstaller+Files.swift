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
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?
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

        let successCount = results.filter { $0.1 }.count
        let failedCount = results.count - successCount

        if failedCount > 0 {
            Logger.shared.error("有 \(failedCount) 个文件下载失败")
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
        gameInfo: GameVersionInfo? = nil
    ) async -> Bool {
        if file.source == .curseforge,
           let projectId = file.curseForgeProjectId,
           let fileId = file.curseForgeFileId {
            return await downloadCurseForgeFile(
                projectId: projectId,
                fileId: fileId,
                resourceDir: resourceDir,
                gameInfo: gameInfo
            )
        }
        return await downloadModrinthFile(file: file, resourceDir: resourceDir)
    }

    private static func downloadCurseForgeFile(
        projectId: Int,
        fileId: Int,
        resourceDir: URL,
        gameInfo: GameVersionInfo? = nil
    ) async -> Bool {
        let fileDetail = await CurseForgeService.fetchFileDetail(projectId: projectId, fileId: fileId)

        if let fileDetail = fileDetail {
            if await downloadCurseForgeFileWithDetail(
                fileDetail: fileDetail,
                projectId: projectId,
                resourceDir: resourceDir
            ) {
                return true
            }
        }
        return false
    }

    private static func downloadCurseForgeFileWithDetail(
        fileDetail: CurseForgeModFileDetail,
        projectId: Int,
        resourceDir: URL
    ) async -> Bool {
        do {
            let downloadUrl: String
            if let directUrl = fileDetail.downloadUrl, !directUrl.isEmpty {
                downloadUrl = directUrl
            } else {
                downloadUrl = URLConfig.API.CurseForge.fallbackDownloadUrl(
                    fileId: fileDetail.id,
                    fileName: fileDetail.fileName
                ).absoluteString
            }

            let effectiveModDetail = try await CurseForgeService.fetchModDetailThrowing(modId: projectId)
            let subDirectory = effectiveModDetail.directoryName
            let destinationPath = resourceDir
                .appendingPathComponent(subDirectory)
                .appendingPathComponent(fileDetail.fileName)

            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let downloadedFile = try await DownloadManager.downloadFile(
                urlString: downloadUrl,
                destinationURL: destinationPath,
                expectedSha1: fileDetail.hash?.value
            )

            if let hash = AppServices.modScanner.sha1Hash(of: downloadedFile) {
                if let cfAsModrinth = CFToModrinthAdapter.convertProjectDetail(effectiveModDetail) {
                    var detailWithFile = cfAsModrinth
                    detailWithFile.fileName = fileDetail.fileName
                    detailWithFile.type = detailWithFile.projectType
                    AppServices.modScanner.saveToCache(hash: hash, detail: detailWithFile)
                }
            }

            return true
        } catch {
            Logger.shared.error("下载 CurseForge 文件失败: \(fileDetail.fileName)")
            return false
        }
    }

    private static func filterFiles(
        from modDetail: CurseForgeModDetail,
        projectId: Int,
        gameVersion: String?,
        modLoaderType: Int?
    ) -> [CurseForgeModFileDetail] {
        var files: [CurseForgeModFileDetail] = []

        if let latestFiles = modDetail.latestFiles, !latestFiles.isEmpty {
            files = latestFiles
        } else if let latestFilesIndexes = modDetail.latestFilesIndexes, !latestFilesIndexes.isEmpty {
            var fileIndexMap: [Int: [CurseForgeFileIndex]] = [:]
            for index in latestFilesIndexes {
                fileIndexMap[index.fileId, default: []].append(index)
            }

            for (fileId, indexes) in fileIndexMap {
                guard let firstIndex = indexes.first else { continue }
                let gameVersions = indexes.map { $0.gameVersion }
                let downloadUrl = URLConfig.API.CurseForge.fallbackDownloadUrl(
                    fileId: fileId,
                    fileName: firstIndex.filename
                ).absoluteString

                let fileDetail = CurseForgeModFileDetail(
                    id: fileId,
                    displayName: firstIndex.filename,
                    fileName: firstIndex.filename,
                    downloadUrl: downloadUrl,
                    fileDate: "",
                    releaseType: firstIndex.releaseType,
                    gameVersions: gameVersions,
                    dependencies: nil,
                    changelog: nil,
                    fileLength: nil,
                    hash: nil,
                    hashes: nil,
                    modules: nil,
                    projectId: projectId,
                    projectName: modDetail.name,
                    authors: modDetail.authors
                )
                files.append(fileDetail)
            }
        }

        if let gameVersion = gameVersion {
            files = files.filter { $0.gameVersions.contains(gameVersion) }
        }

        if let modLoaderType = modLoaderType,
           let latestFilesIndexes = modDetail.latestFilesIndexes {
            let matchingIds = Set(
                latestFilesIndexes
                    .filter { $0.modLoader == modLoaderType }
                    .map { $0.fileId }
            )
            files = files.filter { matchingIds.contains($0.id) }
        }

        return files
    }

    private static func downloadModrinthFile(file: ModrinthIndexFile, resourceDir: URL) async -> Bool {
        guard let urlString = file.downloads.first, !urlString.isEmpty else {
            Logger.shared.error("文件无可用下载链接: \(file.path)")
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
                expectedSha1: file.hashes["sha1"]
            )
        } catch {
            Logger.shared.error("下载文件失败: \(file.path)")
            return false
        }

        if let hash = AppServices.modScanner.sha1Hash(of: downloadedFile),
           var detailWithFile = try? await ModrinthService.fetchModrinthDetailThrowing(by: hash) {
            let fileUrl = URL(fileURLWithPath: file.path)
            detailWithFile.fileName = fileUrl.lastPathComponent
            detailWithFile.type = AppPaths.resourceType(for: fileUrl)
            AppServices.modScanner.saveToCache(hash: hash, detail: detailWithFile)
        }
        return true
    }
}
