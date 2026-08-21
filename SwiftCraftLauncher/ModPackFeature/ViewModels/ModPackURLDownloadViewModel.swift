//
//  ModPackURLDownloadViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Manages downloading a modpack from a user-provided URL.
@MainActor
@Observable
final class ModPackURLDownloadViewModel {
    var urlString: String = ""
    var isDownloading = false
    var downloadProgress: Int64 = 0
    var downloadTotalSize: Int64 = 0
    var errorMessage: String?

    var isURLValid: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var downloadTaskID: UUID?
    private(set) var isHidden = false

    func startDownload(onComplete: @escaping (URL) -> Void, onFailure: @escaping () -> Void = { }) {
        guard let url = URL(string: urlString) else {
            errorMessage = "error.network.invalid_url".localized()
            onFailure()
            return
        }

        isDownloading = true
        isHidden = false
        errorMessage = nil
        downloadProgress = 0
        downloadTotalSize = 0

        downloadTaskID = InstallationTaskManager.shared.start { [self] in
            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("modpack_url_download")
                    .appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(
                    at: tempDir,
                    withIntermediateDirectories: true,
                )

                let filename = url.lastPathComponent.isEmpty ? "modpack.zip" : url.lastPathComponent
                let savePath = tempDir.appendingPathComponent(filename)

                _ = try await ProgressDownloadManager.downloadFile(
                    urlString: url.absoluteString,
                    destinationURL: savePath,
                ) { [weak self] downloaded, total in
                    guard let self else { return }
                    Task { @MainActor in
                        downloadProgress = downloaded
                        if total > 0 {
                            downloadTotalSize = total
                        }
                    }
                }

                guard !Task.isCancelled else { return }
                isDownloading = false
                onComplete(savePath)
            } catch {
                guard !Task.isCancelled else { return }
                isDownloading = false
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    return
                }
                let globalError = GlobalError.from(error)
                errorMessage = globalError.localizedDescription
                DIContainer.shared.core.errorHandler.handle(globalError)
                onFailure()
            }
        }
    }

    func cancel() {
        InstallationTaskManager.shared.cancel(downloadTaskID)
        downloadTaskID = nil
        isDownloading = false
    }

    func hide() {
        isHidden = true
    }
}
