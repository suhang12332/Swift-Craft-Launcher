//
//  ModPackInstallState.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Tracks progress state during mod pack installation.
@MainActor
@Observable
final class ModPackInstallState {
    var isInstalling = false
    var filesProgress: Double = 0
    var dependenciesProgress: Double = 0
    var overridesProgress: Double = 0
    var currentFile: String = ""
    var currentDependency: String = ""
    var currentOverride: String = ""
    var filesTotal: Int = 0
    var dependenciesTotal: Int = 0
    var overridesTotal: Int = 0
    var filesCompleted: Int = 0
    var dependenciesCompleted: Int = 0
    var overridesCompleted: Int = 0

    /// Resets all progress state to initial values.
    func reset() {
        isInstalling = false
        filesProgress = 0
        dependenciesProgress = 0
        overridesProgress = 0
        currentFile = ""
        currentDependency = ""
        currentOverride = ""
        filesTotal = 0
        dependenciesTotal = 0
        overridesTotal = 0
        filesCompleted = 0
        dependenciesCompleted = 0
        overridesCompleted = 0
    }

    /// Begins a new installation with the specified totals.
    func startInstallation(
        filesTotal: Int,
        dependenciesTotal: Int,
        overridesTotal: Int = 0,
    ) {
        self.filesTotal = filesTotal
        self.dependenciesTotal = dependenciesTotal
        if self.overridesTotal == 0 {
            self.overridesTotal = overridesTotal
        }
        isInstalling = true
        filesProgress = 0
        dependenciesProgress = 0
        if overridesCompleted == 0 {
            overridesProgress = 0
        }
        filesCompleted = 0
        dependenciesCompleted = 0
    }

    /// Updates progress for a file download.
    func updateFilesProgress(fileName: String, completed: Int, total: Int) {
        currentFile = fileName
        filesCompleted = completed
        filesTotal = total
        filesProgress = ProgressUtil.calculateProgress(completed: completed, total: total)
    }

    /// Updates progress for a dependency download.
    func updateDependenciesProgress(
        dependencyName: String,
        completed: Int,
        total: Int,
    ) {
        currentDependency = dependencyName
        dependenciesCompleted = completed
        dependenciesTotal = total
        dependenciesProgress = ProgressUtil.calculateProgress(
            completed: completed,
            total: total,
        )
    }

    /// Updates progress for an override file.
    func updateOverridesProgress(
        overrideName: String,
        completed: Int,
        total: Int,
    ) {
        currentOverride = overrideName
        overridesCompleted = completed
        overridesTotal = total
        overridesProgress = ProgressUtil.calculateProgress(
            completed: completed,
            total: total,
        )
    }
}
