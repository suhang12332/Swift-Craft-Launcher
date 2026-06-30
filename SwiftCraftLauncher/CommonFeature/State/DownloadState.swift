//
//  DownloadState.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tracks download progress for game core files and resources.
@MainActor
class DownloadState: ObservableObject {
    @Published var isDownloading = false
    @Published var coreProgress: Double = 0
    @Published var resourcesProgress: Double = 0
    @Published var currentCoreFile: String = ""
    @Published var currentResourceFile: String = ""
    @Published var coreTotalFiles: Int = 0
    @Published var resourcesTotalFiles: Int = 0
    @Published var coreCompletedFiles: Int = 0
    @Published var resourcesCompletedFiles: Int = 0
    @Published var isCancelled = false

    /// Resets all progress values to the default state.
    func reset() {
        isDownloading = false
        coreProgress = 0
        resourcesProgress = 0
        currentCoreFile = ""
        currentResourceFile = ""
        coreTotalFiles = 0
        resourcesTotalFiles = 0
        coreCompletedFiles = 0
        resourcesCompletedFiles = 0
        isCancelled = false
    }

    /// Begins tracking a new download operation.
    /// - Parameters:
    ///   - coreTotalFiles: The total number of core files to download.
    ///   - resourcesTotalFiles: The total number of resource files to download.
    func startDownload(coreTotalFiles: Int, resourcesTotalFiles: Int) {
        self.coreTotalFiles = coreTotalFiles
        self.resourcesTotalFiles = resourcesTotalFiles
        isDownloading = true
        coreProgress = 0
        resourcesProgress = 0
        coreCompletedFiles = 0
        resourcesCompletedFiles = 0
        isCancelled = false
    }

    /// Cancels the download by setting the cancelled flag.
    func cancel() {
        isCancelled = true
    }

    /// Updates progress for a specific download type.
    /// - Parameters:
    ///   - fileName: The current file being processed.
    ///   - completed: The number of completed files.
    ///   - total: The total number of files.
    ///   - type: Whether this is a core or resources download.
    func updateProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: MinecraftFileManager.DownloadType,
    ) {
        switch type {
        case .core:
            updateCoreProgress(fileName: fileName, completed: completed, total: total)
        case .resources:
            updateResourcesProgress(fileName: fileName, completed: completed, total: total)
        }
    }

    private func updateCoreProgress(fileName: String, completed: Int, total: Int) {
        currentCoreFile = fileName
        coreCompletedFiles = completed
        coreTotalFiles = total
        coreProgress = calculateProgress(completed: completed, total: total)
    }

    private func updateResourcesProgress(fileName: String, completed: Int, total: Int) {
        currentResourceFile = fileName
        resourcesCompletedFiles = completed
        resourcesTotalFiles = total
        resourcesProgress = calculateProgress(completed: completed, total: total)
    }

    private func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}
