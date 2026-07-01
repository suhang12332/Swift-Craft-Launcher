//
//  ModPackDownloadService.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import ZIPFoundation

/// Downloads modpack archives and game icons with progress reporting.
@MainActor
final class ModPackDownloadService {
    var progressHandler: ((Int64, Int64) -> Void)?
    var onError: ((String, String) -> Void)?
    private let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    /// Cleans up temporary download and extraction directories.
    func cleanupTempFiles() {
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let tempBaseDir = fm.temporaryDirectory
            let downloadDir = tempBaseDir.appendingPathComponent("modpack_download")
            if fm.fileExists(atPath: downloadDir.path) {
                do {
                    try fm.removeItem(at: downloadDir)
                    AppLog.modPack.info("Cleaned up temp download directory: \(downloadDir.path)")
                } catch {
                    AppLog.modPack.error("Failed to clean up temp download directory: \(error.localizedDescription)")
                }
            }
            let extractionDir = tempBaseDir.appendingPathComponent("modpack_extraction")
            if fm.fileExists(atPath: extractionDir.path) {
                do {
                    try fm.removeItem(at: extractionDir)
                    AppLog.modPack.info("Cleaned up temp extraction directory: \(extractionDir.path)")
                } catch {
                    AppLog.modPack.error("Failed to clean up temp extraction directory: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Downloads a modpack file to a temporary directory.
    /// - Parameters:
    ///   - file: The version file to download.
    ///   - projectDetail: The project detail for reference.
    /// - Returns: The local file URL, or nil on failure.
    func downloadModPackFile(
        file: ModrinthVersionFile,
        projectDetail _: ModrinthProjectDetail,
    ) async -> URL? {
        do {
            let tempDir = try createTempDirectory(for: "modpack_download")
            let savePath = tempDir.appendingPathComponent(file.filename)
            do {
                _ = try await downloadFileWithProgress(
                    urlString: file.url,
                    destinationURL: savePath,
                    expectedSha1: file.hashes.sha1,
                )
                return savePath
            } catch {
                if error is CancellationError || Task.isCancelled {
                    AppLog.modPack.info("Modpack download cancelled")
                    return nil
                }
                let globalError = GlobalError.from(error)
                onError?(globalError.localizedDescription, globalError.i18nKey)
                return nil
            }
        } catch {
            let globalError = GlobalError.from(error)
            errorHandler.handle(globalError)
            return nil
        }
    }

    /// Downloads the game icon for a project.
    /// - Parameters:
    ///   - projectDetail: The project detail containing the icon URL.
    ///   - gameName: The game name to associate with the icon.
    /// - Returns: The icon file name, or nil on failure.
    func downloadGameIcon(
        projectDetail: ModrinthProjectDetail,
        gameName: String,
    ) async -> String? {
        do {
            guard let iconUrl = projectDetail.iconUrl else {
                return nil
            }

            let gameDirectory = AppPaths.profileDirectory(gameName: gameName)
            try FileManager.default.createDirectory(
                at: gameDirectory,
                withIntermediateDirectories: true,
            )

            let iconFileName = "default_game_icon.png"
            let iconPath = gameDirectory.appendingPathComponent(iconFileName)

            do {
                _ = try await DownloadManager.downloadFile(
                    urlString: iconUrl,
                    destinationURL: iconPath,
                    expectedSha1: nil,
                )
                return iconFileName
            } catch {
                onError?(
                    "Failed to download game icon",
                    "error.network.icon_download_failed",
                )
                return nil
            }
        } catch {
            onError?(
                "Failed to download game icon",
                "error.network.icon_download_failed",
            )
            return nil
        }
    }

    /// Extracts a modpack archive to a temporary directory.
    /// - Parameter modPackPath: The path to the modpack archive.
    /// - Returns: The extraction directory, or nil on failure.
    func extractModPack(modPackPath: URL) async -> URL? {
        do {
            let fileExtension = modPackPath.pathExtension.lowercased()

            guard fileExtension == AppConstants.FileExtensions.zip || fileExtension == AppConstants.FileExtensions.mrpack else {
                onError?(
                    "Unsupported modpack format: \(fileExtension)",
                    "error.resource.unsupported_modpack_format",
                )
                return nil
            }

            let modPackPathString = modPackPath.path
            guard FileManager.default.fileExists(atPath: modPackPathString) else {
                onError?(
                    "Modpack file does not exist: \(modPackPathString)",
                    "error.filesystem.file_not_found",
                )
                return nil
            }

            let sourceAttributes = try FileManager.default.attributesOfItem(
                atPath: modPackPathString,
            )
            let sourceSize = sourceAttributes[.size] as? Int64 ?? 0
            guard sourceSize > 0 else {
                onError?("Modpack file is empty", "error.resource.modpack_empty")
                return nil
            }

            let tempDir = try createTempDirectory(for: "modpack_extraction")
            try FileManager.default.unzipItem(at: modPackPath, to: tempDir)
            return tempDir
        } catch {
            onError?(
                "Failed to extract modpack: \(error.localizedDescription)",
                "error.filesystem.extraction_failed",
            )
            return nil
        }
    }

    private func downloadFileWithProgress(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String?,
    ) async throws -> URL {
        try await ProgressDownloadManager.downloadFile(
            urlString: urlString,
            destinationURL: destinationURL,
            expectedSha1: expectedSha1,
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
            withIntermediateDirectories: true,
        )
        return tempDir
    }
}
