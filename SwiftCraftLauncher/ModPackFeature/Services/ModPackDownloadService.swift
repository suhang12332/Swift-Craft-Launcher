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
                if error is CancellationError || Task.isCancelled {
                    Logger.shared.info("整合包下载已取消")
                    return nil
                }
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    Logger.shared.info("整合包下载已取消")
                    return nil
                }
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
        return try await ProgressDownloadManager.downloadFile(
            urlString: urlString,
            destinationURL: destinationURL,
            expectedSha1: expectedSha1
        ) { [weak self] downloadedBytes, totalBytes in
            self?.progressHandler?(downloadedBytes, totalBytes)
        }
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
