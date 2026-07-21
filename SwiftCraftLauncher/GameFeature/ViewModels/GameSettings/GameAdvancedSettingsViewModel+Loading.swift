//
//  GameAdvancedSettingsViewModel+Loading.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Extension providing settings loading and Java version info retrieval.
extension GameAdvancedSettingsViewModel {
    func loadCurrentSettings() {
        guard let game = currentGame else { return }
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        let xms = game.xms == 0 ? DIContainer.shared.ui.gameSettingsManager.globalXms : game.xms
        let xmx = game.xmx == 0 ? DIContainer.shared.ui.gameSettingsManager.globalXmx : game.xmx
        memoryRange = Double(xms) ... Double(xmx)
        environmentVariables = game.environmentVariables
        javaPath = game.javaPath

        let jvmArgs = game.jvmArguments.trimmingCharacters(in: .whitespacesAndNewlines)
        if jvmArgs.isEmpty {
            customJvmArguments = ""
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        } else {
            customJvmArguments = parseExistingJvmArguments(jvmArgs) ? "" : jvmArgs
            if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
                selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
                applyOptimizationPreset(.balanced)
            }
        }
    }

    /// Loads the `java --version` output for the currently effective Java path.
    func loadJavaVersionInfo() {
        let path = effectiveJavaPath

        guard !path.isEmpty else {
            javaVersionInfo = ""
            return
        }

        Task {
            let info = DIContainer.shared.system.javaManager.getJavaVersionInfo(at: path) ?? ""
            await MainActor.run {
                if self.effectiveJavaPath == path {
                    self.javaVersionInfo = info
                }
            }
        }
    }
}
