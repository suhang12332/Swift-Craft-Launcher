//
//  JavaDownloadState.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// An observable state object that tracks the progress of a Java runtime download.
@MainActor
class JavaDownloadState: ObservableObject {

    /// Indicates whether a download is currently in progress.
    @Published var isDownloading = false

    /// The download progress as a value between 0 and 1.
    @Published var progress: Double = 0

    /// The name of the file currently being downloaded.
    @Published var currentFile: String = ""

    /// Indicates whether the download has been cancelled.
    @Published var isCancelled = false

    /// The Java version being downloaded.
    @Published var version: String = ""

    /// A message describing the most recent error, if any.
    @Published var errorMessage: String = ""

    /// Indicates whether an error has occurred during the download.
    @Published var hasError = false

    /// Resets all properties to their initial values.
    func reset() {
        isDownloading = false
        progress = 0
        currentFile = ""
        isCancelled = false
        version = ""
        errorMessage = ""
        hasError = false
    }

    /// Begins tracking a new download for the specified version.
    /// - Parameter version: The Java version to download.
    func startDownload(version: String) {
        self.version = version
        self.isDownloading = true
        self.progress = 0
        self.isCancelled = false
        self.hasError = false
        self.errorMessage = ""
    }

    /// Cancels the current download.
    func cancel() {
        isCancelled = true
    }

    /// Updates the current download progress.
    /// - Parameters:
    ///   - fileName: The name of the file being downloaded.
    ///   - progress: The current progress as a value between 0 and 1.
    func updateProgress(fileName: String, progress: Double) {
        currentFile = fileName
        self.progress = progress
    }

    /// Records an error and stops the download.
    /// - Parameter message: A description of the error.
    func setError(_ message: String) {
        hasError = true
        errorMessage = message
        isDownloading = false
    }
}
