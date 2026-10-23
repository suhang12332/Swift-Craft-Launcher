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
    var progressHandler: (@Sendable (Int64, Int64) -> Void)?
    var onError: ((String, String) -> Void)?

    /// Cleans up temporary download and extraction directories.
    func cleanupTempFiles() {
        Task.detached(priority: .utility) {
            for purpose in TemporaryDirectoryPurpose.modpackInstall {
                TemporaryDirectory.removeAll(purpose: purpose)
            }
            AppLog.modPack.info("Cleaned up modpack temporary directories")
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
        await downloadArchive(
            urlString: file.url,
            filename: file.filename,
            expectedSha1: file.hashes.sha1,
            purpose: .modpackDownload,
        )
    }

    /// Downloads a modpack archive from an arbitrary URL to a temporary directory.
    /// - Parameter url: The URL to download from.
    /// - Returns: The local archive URL, or `nil` on failure or cancellation.
    func downloadModPackArchive(from url: URL) async -> URL? {
        let filename = url.lastPathComponent.isEmpty ? "modpack.zip" : url.lastPathComponent
        return await downloadArchive(
            urlString: url.absoluteString,
            filename: filename,
            expectedSha1: nil,
            purpose: .modpackURLDownload,
        )
    }

    private func downloadArchive(
        urlString: String,
        filename: String,
        expectedSha1: String?,
        purpose: TemporaryDirectoryPurpose,
    ) async -> URL? {
        do {
            let temporary = try TemporaryDirectory(purpose: purpose)
            var keepDirectory = false
            defer {
                if !keepDirectory {
                    temporary.remove()
                }
            }

            let savePath = temporary.url.appendingPathComponent(filename)

            do {
                _ = try await downloadFileWithProgress(
                    urlString: urlString,
                    destinationURL: savePath,
                    expectedSha1: expectedSha1,
                )
                keepDirectory = true
                return savePath
            } catch {
                if error is CancellationError || Task.isCancelled {
                    AppLog.modPack.info("Modpack download cancelled: \(purpose.directoryName)")
                    return nil
                }
                let globalError = GlobalError.from(error)
                onError?(globalError.localizedDescription, globalError.i18nKey)
                return nil
            }
        } catch {
            let globalError = GlobalError.from(error)
            DIContainer.shared.core.errorHandler.handle(globalError)
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
        guard let iconUrlString = projectDetail.iconUrl,
              let iconURL = URL(string: iconUrlString) else {
            return nil
        }

        do {
            let iconPresent = try await GameIconStore.downloadIfMissing(
                from: iconURL,
                gameName: gameName,
            )
            return iconPresent ? AppConstants.defaultGameIcon : nil
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

            let temporary = try TemporaryDirectory(purpose: .modpackExtraction)
            var keepDirectory = false
            defer {
                if !keepDirectory {
                    temporary.remove()
                }
            }

            try FileManager.default.unzipItem(at: modPackPath, to: temporary.url)
            keepDirectory = true
            return temporary.url
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
        let handler = progressHandler
        return try await ProgressDownloadManager.downloadFile(
            urlString: urlString,
            destinationURL: destinationURL,
            expectedSha1: expectedSha1,
        ) { downloadedBytes, totalBytes in
            handler?(downloadedBytes, totalBytes)
        }
    }
}
