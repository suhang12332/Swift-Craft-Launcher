//
//  ModPackInstallState.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Tracks progress state during mod pack installation.
@MainActor
class ModPackInstallState: ObservableObject {
    @Published var isInstalling = false
    @Published var filesProgress: Double = 0
    @Published var dependenciesProgress: Double = 0
    @Published var overridesProgress: Double = 0
    @Published var currentFile: String = ""
    @Published var currentDependency: String = ""
    @Published var currentOverride: String = ""
    @Published var filesTotal: Int = 0
    @Published var dependenciesTotal: Int = 0
    @Published var overridesTotal: Int = 0
    @Published var filesCompleted: Int = 0
    @Published var dependenciesCompleted: Int = 0
    @Published var overridesCompleted: Int = 0

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
        filesProgress = calculateProgress(completed: completed, total: total)
        objectWillChange.send()
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
        dependenciesProgress = calculateProgress(
            completed: completed,
            total: total,
        )
        objectWillChange.send()
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
        overridesProgress = calculateProgress(
            completed: completed,
            total: total,
        )
        objectWillChange.send()
    }

    private func calculateProgress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(completed) / Double(total)))
    }
}
