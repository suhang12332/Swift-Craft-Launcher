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
    /// Cross-thread cancellation flag.
    ///
    /// Written on the main actor and read from the downloader's `CancelActor`
    /// callback, so it is guarded by a lock rather than actor isolation.
    nonisolated private let cancelRequestedFlag = OSAllocatedUnfairLock(initialState: false)

    nonisolated private var cancelRequested: Bool {
        cancelRequestedFlag.withLock { $0 }
    }

    nonisolated private func setCancelRequested(_ value: Bool) {
        cancelRequestedFlag.withLock { $0 = value }
    }

    init() { }

    /// Sets a callback to be invoked when the download window is dismissed.
    func setDismissCallback(_ callback: @escaping () -> Void) {
        dismissCallback = callback
    }

    /// Downloads a specific Java runtime version.
    func downloadJavaRuntime(version: String) async {
        defer {
            currentDownloadTask = nil
            setCancelRequested(false)
        }
        do {
            downloadState.reset()
            downloadState.startDownload(version: version)
            setCancelRequested(false)

            showDownloadWindow()

            DIContainer.shared.system.javaRuntimeDownloader.setProgressCallback { @Sendable [weak self] fileName, completed, total in
                Task { @MainActor in
                    guard let self, !self.downloadState.isCancelled else { return }
                    let progress = total > 0 ? Double(completed) / Double(total) : 0.0
                    self.downloadState.updateProgress(fileName: fileName, progress: progress)
                }
            }

            DIContainer.shared.system.javaRuntimeDownloader.setCancelCallback { @Sendable [weak self] in
                return self?.cancelRequested ?? false
            }

            let task = Task { [javaRuntimeDownloader = DIContainer.shared.system.javaRuntimeDownloader] in
                try await javaRuntimeDownloader.downloadJavaRuntime(for: version)
            }
            currentDownloadTask = task
            try await task.value

            if downloadState.isCancelled || cancelRequested {
                AppLog.game.info("Java download cancelled")
                cleanupCancelledDownload()
                return
            }

            downloadState.isDownloading = false

            closeWindow()
        } catch {
            if error is CancellationError || downloadState.isCancelled || cancelRequested {
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
        setCancelRequested(true)
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
