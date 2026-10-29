//
//  InstallProgressReporter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Publishes progress for the phases of a game installation.
///
/// Replaces the separate core, resources, and per-loader state objects: only one
/// mod loader is installed at a time, so a single loader phase is enough.
@MainActor
@Observable
final class InstallProgressReporter {
    struct PhaseProgress {
        var progress: Double = 0
        var currentFile: String = ""
        var completed: Int = 0
        var total: Int = 0
    }

    private(set) var core = PhaseProgress()
    private(set) var resources = PhaseProgress()
    private(set) var loader = PhaseProgress()
    var isDownloading = false
    var isCancelled = false

    /// Resets all phases and begins tracking a new installation.
    func start(coreTotalFiles: Int, resourcesTotalFiles: Int) {
        core = PhaseProgress(total: coreTotalFiles)
        resources = PhaseProgress(total: resourcesTotalFiles)
        loader = PhaseProgress()
        isDownloading = true
        isCancelled = false
    }

    func updateProgress(
        fileName: String,
        completed: Int,
        total: Int,
        type: MinecraftFileManager.DownloadType,
    ) {
        switch type {
        case .core:
            updateCore(fileName: fileName, completed: completed, total: total)
        case .resources:
            updateResources(fileName: fileName, completed: completed, total: total)
        }
    }

    func updateLoader(fileName: String, completed: Int, total: Int) {
        loader.currentFile = fileName
        loader.completed = completed
        loader.total = total
        loader.progress = ProgressUtil.calculateProgress(completed: completed, total: total)
    }

    func cancel() {
        isCancelled = true
    }

    func reset() {
        core = PhaseProgress()
        resources = PhaseProgress()
        loader = PhaseProgress()
        isDownloading = false
        isCancelled = false
    }

    private func updateCore(fileName: String, completed: Int, total: Int) {
        core.currentFile = fileName
        core.completed = completed
        core.total = total
        core.progress = ProgressUtil.calculateProgress(completed: completed, total: total)
    }

    private func updateResources(fileName: String, completed: Int, total: Int) {
        resources.currentFile = fileName
        resources.completed = completed
        resources.total = total
        resources.progress = ProgressUtil.calculateProgress(completed: completed, total: total)
    }
}
