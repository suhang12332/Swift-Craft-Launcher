//
//  JavaDownloadManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Manages Java runtime downloads and tracks their progress.
@MainActor
@Observable
class JavaDownloadManager {
    var downloadState = JavaDownloadState()
    var isWindowVisible = false

    private var dismissCallback: (() -> Void)?
    private var currentDownloadTask: Task<Void, Error>?

    private final class JobCancellation: @unchecked Sendable {
        let lock = OSAllocatedUnfairLock(initialState: false)

        var isCancelled: Bool { lock.withLock { $0 } }

        func cancel() { lock.withLock { $0 = true } }
    }

    private var currentJobCancellation: JobCancellation?

    init() { }

    /// Sets a callback to be invoked when the download window is dismissed.
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// Downloads a specific Java runtime version.
    func downloadJavaRuntime(version: String) async {
        defer {
            currentDownloadTask = nil
            currentJobCancellation = nil
        }
        let jobCancellation = JobCancellation()
        currentJobCancellation = jobCancellation
        do {
            downloadState.reset()
            downloadState.startDownload(version: version)
            showDownloadWindow()

            DIContainer.shared.system.javaRuntimeDownloader.setProgressCallback { @Sendable [weak self] fileName, completed, total in
                Task { @MainActor in
                    guard let self, !self.downloadState.isCancelled else { return }
                    let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                    self.downloadState.updateProgress(fileName: fileName, progress: progress)
                }
            }

            DIContainer.shared.system.javaRuntimeDownloader.setCancelCallback { @Sendable [weak self] in
                _ = self
                return jobCancellation.isCancelled
            }

            let task = Task { [javaRuntimeDownloader = DIContainer.shared.system.javaRuntimeDownloader] in
                try await javaRuntimeDownloader.downloadJavaRuntime(for: version)
            }
            currentDownloadTask = task
            // The download runs in an unstructured task, so it does not inherit
            // cancellation from whoever triggered it. Game installs now provision
            // Java alongside their own downloads, which means an install can be
            // cancelled while this is still in flight; without this the runtime
            // would keep pulling ~180MB in the background.
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
                jobCancellation.cancel()
            }

            if downloadState.isCancelled || jobCancellation.isCancelled {
                AppLog.game.info("Java download cancelled")
                cleanupCancelledDownload()
                return
            }

            downloadState.isDownloading = false

            closeWindow()
        } catch {
            if error is CancellationError || downloadState.isCancelled || jobCancellation.isCancelled {
                AppLog.game.info("Java download task cancelled")
                cleanupCancelledDownload()
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
        currentJobCancellation?.cancel()
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
