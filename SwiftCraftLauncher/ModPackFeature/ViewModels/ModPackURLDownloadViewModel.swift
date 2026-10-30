//
//  ModPackURLDownloadViewModel.swift
//  ModPackFeature
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
    private(set) var hasCompletedDownload = false

    var isURLValid: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private let installTasks = InstallTaskCoordinator()
    private let downloadService = ModPackDownloadService()

    init() {
        downloadService.progressHandler = { [weak self] downloaded, total in
            guard let self else { return }
            Task { @MainActor in
                self.downloadProgress = downloaded
                if total > 0 {
                    self.downloadTotalSize = total
                }
            }
        }
        downloadService.onError = { [weak self] message, i18nKey in
            guard let self else { return }
            Task { @MainActor in
                self.handleDownloadError(message: message, i18nKey: i18nKey)
            }
        }
    }

    func startDownload(onComplete: @escaping (URL) -> Void, onFailure: @escaping () -> Void = { }) {
        guard let url = URL(string: urlString), isURLValid else {
            errorMessage = "error.network.invalid_url".localized()
            onFailure()
            return
        }

        isDownloading = true
        errorMessage = nil
        downloadProgress = 0
        downloadTotalSize = 0
        hasCompletedDownload = false

        installTasks.start { [weak self] in
            guard let self else { return }
            let archivePath = await downloadService.downloadModPackArchive(from: url)

            guard !Task.isCancelled else { return }

            isDownloading = false
            guard let archivePath else {
                onFailure()
                return
            }
            hasCompletedDownload = true
            onComplete(archivePath)
        }
    }

    func cancel() {
        let wasDownloading = installTasks.isRunning
        installTasks.cancel()
        isDownloading = false
        guard wasDownloading, !hasCompletedDownload else { return }
        downloadService.cleanupTempFiles()
    }

    private func handleDownloadError(message: String, i18nKey: String) {
        errorMessage = message
        DIContainer.shared.core.errorHandler.handle(
            GlobalError.resource(
                i18nKey: i18nKey,
                level: .notification,
                message: message,
            ),
        )
    }
}
