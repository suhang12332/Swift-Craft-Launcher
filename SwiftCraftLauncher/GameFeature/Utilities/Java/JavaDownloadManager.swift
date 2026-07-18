//
//  JavaDownloadManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages Java runtime downloads and tracks their progress.
class JavaDownloadManager: ObservableObject {
    @Published var downloadState = JavaDownloadState()
    @Published var isWindowVisible = false

    private var dismissCallback: (() -> Void)?
    private var currentDownloadTask: Task<Void, Error>?
    private var cancelRequested = false

    init() { }

    /// Sets a callback to be invoked when the download window is dismissed.
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// Downloads a specific Java runtime version.
    func downloadJavaRuntime(version: String) async {
        defer {
            currentDownloadTask = nil
            cancelRequested = false
        }
        do {
            downloadState.reset()
            downloadState.startDownload(version: version)
            cancelRequested = false

            await showDownloadWindow()

            DIContainer.shared.system.javaRuntimeDownloader.setProgressCallback { [weak self] fileName, completed, total in
                Task { @MainActor in
                    guard let self, !self.downloadState.isCancelled else { return }
                    let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                    self.downloadState.updateProgress(fileName: fileName, progress: progress)
                }
            }

            DIContainer.shared.system.javaRuntimeDownloader.setCancelCallback { [weak self] in
                return self?.cancelRequested ?? false
            }

            let task = Task { [javaRuntimeDownloader = DIContainer.shared.system.javaRuntimeDownloader] in
                try await javaRuntimeDownloader.downloadJavaRuntime(for: version)
            }
            currentDownloadTask = task
            try await task.value

            if downloadState.isCancelled || cancelRequested {
                AppLog.game.info("Java download cancelled")
                await cleanupCancelledDownload()
                return
            }

            downloadState.isDownloading = false

            await closeWindow()
        } catch {
            if error is CancellationError || downloadState.isCancelled || cancelRequested {
                AppLog.game.info("Java download task cancelled")
                await cleanupCancelledDownload()
                return
            }
            if !downloadState.isCancelled {
                downloadState.setError(error.localizedDescription)
            }
        }
    }

    /// Cancels the current download.
    @MainActor
    func cancelDownload() {
        guard downloadState.isDownloading else {
            closeWindow()
            return
        }
        cancelRequested = true
        downloadState.cancel()
        currentDownloadTask?.cancel()
    }

    /// Retries the previously attempted download.
    func retryDownload() {
        guard !downloadState.version.isEmpty else { return }
        Task {
            await downloadJavaRuntime(version: downloadState.version)
        }
    }

    @MainActor
    private func showDownloadWindow() {
        DIContainer.shared.ui.windowManager.openWindow(id: .javaDownload)
        isWindowVisible = true
    }

    /// Closes the download window and resets state.
    @MainActor
    func closeWindow() {
        DIContainer.shared.ui.windowManager.closeWindow(id: .javaDownload)
        isWindowVisible = false
        downloadState.reset()
        dismissCallback?()
    }

    /// Cleans up resources after a cancelled download.
    @MainActor
    func cleanupCancelledDownload() {
        let version = downloadState.version
        AppLog.game.info("Cleaning up cancelled Java download for version: \(version)")
        closeWindow()
    }
}
