import Foundation
import ZIPFoundation

@MainActor
final class ModPackDownloadService {
    var progressHandler: ((Int64, Int64) -> Void)?
    var errorHandler: ((String, String) -> Void)?

    func cleanupTempFiles() {
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let tempBaseDir = fm.temporaryDirectory
            let downloadDir = tempBaseDir.appendingPathComponent("modpack_download")
            if fm.fileExists(atPath: downloadDir.path) {
                do {
                    try fm.removeItem(at: downloadDir)
                    Logger.shared.info("已清理临时下载目录: \(downloadDir.path)")
                } catch {
                    Logger.shared.warning("清理临时下载目录失败: \(error.localizedDescription)")
                }
            }
            let extractionDir = tempBaseDir.appendingPathComponent("modpack_extraction")
            if fm.fileExists(atPath: extractionDir.path) {
                do {
                    try fm.removeItem(at: extractionDir)
                    Logger.shared.info("已清理临时解压目录: \(extractionDir.path)")
                } catch {
                    Logger.shared.warning("清理临时解压目录失败: \(error.localizedDescription)")
                }
            }
        }
    }

    func downloadModPackFile(
        file: ModrinthVersionFile,
        projectDetail: ModrinthProjectDetail
    ) async -> URL? {
        do {
            let tempDir = try createTempDirectory(for: "modpack_download")
            let savePath = tempDir.appendingPathComponent(file.filename)
            do {
                _ = try await downloadFileWithProgress(
                    urlString: file.url,
                    destinationURL: savePath,
                    expectedSha1: file.hashes.sha1
                )
                return savePath
            } catch {
                let globalError = GlobalError.from(error)
                errorHandler?(globalError.chineseMessage, globalError.i18nKey)
                return nil
            }
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String
    ) async -> String? {
        do {
            guard let iconUrl = projectDetail.iconUrl else {
                return nil
            }

            let gameDirectory = AppPaths.profileDirectory(gameName: gameName)
            try FileManager.default.createDirectory(
                at: gameDirectory,
                withIntermediateDirectories: true
            )

            let iconFileName = "default_game_icon.png"
            let iconPath = gameDirectory.appendingPathComponent(iconFileName)

            do {
                _ = try await DownloadManager.downloadFile(
                    urlString: iconUrl,
                    destinationURL: iconPath,
                    expectedSha1: nil
                )
                return iconFileName
            } catch {
                errorHandler?(
                    "下载游戏图标失败",
                    "error.network.icon_download_failed"
                )
                return nil
            }
        } catch {
            errorHandler?(
                "下载游戏图标失败",
                "error.network.icon_download_failed"
            )
            return nil
        }
    }

    func extractModPack(modPackPath: URL) async -> URL? {
        do {
            let fileExtension = modPackPath.pathExtension.lowercased()

            guard fileExtension == "zip" || fileExtension == "mrpack" else {
                errorHandler?(
                    "不支持的整合包格式: \(fileExtension)",
                    "error.resource.unsupported_modpack_format"
                )
                return nil
            }

            let modPackPathString = modPackPath.path
            guard FileManager.default.fileExists(atPath: modPackPathString) else {
                errorHandler?(
                    "整合包文件不存在: \(modPackPathString)",
                    "error.filesystem.file_not_found"
                )
                return nil
            }

            let sourceAttributes = try FileManager.default.attributesOfItem(
                atPath: modPackPathString
            )
            let sourceSize = sourceAttributes[.size] as? Int64 ?? 0
            guard sourceSize > 0 else {
                errorHandler?("整合包文件为空", "error.resource.modpack_empty")
                return nil
            }

            let tempDir = try createTempDirectory(for: "modpack_extraction")
            try FileManager.default.unzipItem(at: modPackPath, to: tempDir)
            return tempDir
        } catch {
            errorHandler?(
                "解压整合包失败: \(error.localizedDescription)",
                "error.filesystem.extraction_failed"
            )
            return nil
        }
    }

    // MARK: - Private

    private func downloadFileWithProgress(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String?
    ) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的下载地址",
                i18nKey: "error.validation.invalid_download_url",
                level: .notification
            )
        }

        let finalURL: URL = {
            if let host = url.host,
               host == "github.com" || host == "raw.githubusercontent.com" {
                return URLConfig.applyGitProxyIfNeeded(url)
            }
            return url
        }()

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            if let expectedSha1 = expectedSha1, !expectedSha1.isEmpty {
                let actualSha1 = try DownloadManager.calculateFileSHA1(at: destinationURL)
                if actualSha1 == expectedSha1 {
                    if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                       let fileSize = attributes[.size] as? Int64 {
                        progressHandler?(fileSize, fileSize)
                    }
                    return destinationURL
                }
            } else {
                if let attributes = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    progressHandler?(fileSize, fileSize)
                }
                return destinationURL
            }
        }

        let fileSize = try await getFileSize(from: finalURL)
        progressHandler?(0, fileSize)

        let progressCallback: (Int64, Int64) -> Void = { [weak self] downloadedBytes, totalBytes in
            Task { @MainActor in
                self?.progressHandler?(downloadedBytes, totalBytes)
            }
        }
        let progressTracker = ModPackDownloadProgressTracker(
            totalSize: fileSize,
            progressCallback: progressCallback
        )

        let config = URLSessionConfiguration.default
        let session = URLSession(
            configuration: config,
            delegate: progressTracker,
            delegateQueue: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            progressTracker.completionHandler = { result in
                switch result {
                case .success(let tempURL):
                    do {
                        if let expectedSha1 = expectedSha1, !expectedSha1.isEmpty {
                            let actualSha1 = try DownloadManager.calculateFileSHA1(at: tempURL)
                            if actualSha1 != expectedSha1 {
                                throw GlobalError.validation(
                                    chineseMessage: "SHA1 校验失败",
                                    i18nKey: "error.validation.sha1_check_failed",
                                    level: .notification
                                )
                            }
                        }

                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.replaceItem(
                                at: destinationURL,
                                withItemAt: tempURL,
                                backupItemName: nil,
                                options: [],
                                resultingItemURL: nil
                            )
                        } else {
                            try fileManager.moveItem(at: tempURL, to: destinationURL)
                        }

                        continuation.resume(returning: destinationURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let downloadTask = session.downloadTask(with: finalURL)
            downloadTask.resume()
        }
    }

    private func getFileSize(from url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小",
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification
            )
        }

        guard let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.download(
                chineseMessage: "无法获取文件大小",
                i18nKey: "error.download.cannot_get_file_size",
                level: .notification
            )
        }

        return fileSize
    }

    private func createTempDirectory(for purpose: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(purpose)
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }
}

