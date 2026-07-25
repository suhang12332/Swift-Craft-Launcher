//
//  GameAdvancedSettingsViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// View model for the game advanced settings view, managing JVM arguments, memory, garbage collector, and Java path configuration.
@MainActor
@Observable
final class GameAdvancedSettingsViewModel {
    var gameRepository: GameRepository?

    var memoryRange: ClosedRange<Double>
    var selectedGarbageCollector: GarbageCollector
    var optimizationPreset: OptimizationPreset
    var customJvmArguments: String
    var environmentVariables: String
    var javaPath: String
    var javaVersionInfo: String
    var isLoadingSettings: Bool

    var enableOptimizations: Bool = true
    var enableAikarFlags: Bool = false
    var enableMemoryOptimizations: Bool = true
    var enableThreadOptimizations: Bool = true
    var enableNetworkOptimizations: Bool = false

    var saveTask: Task<Void, Never>?

    init() {
        memoryRange = Double(DIContainer.shared.ui.gameSettingsManager.globalXms) ... Double(DIContainer.shared.ui.gameSettingsManager.globalXmx)
        selectedGarbageCollector = .g1gc
        optimizationPreset = .balanced
        customJvmArguments = ""
        environmentVariables = ""
        javaPath = ""
        javaVersionInfo = ""
        isLoadingSettings = false
    }

    var currentGame: GameVersionInfo? {
        guard let gameId = DIContainer.shared.core.selectedGameManager.selectedGameId else { return nil }
        return gameRepository?.getGame(by: gameId)
    }

    /// A Boolean value indicating whether custom JVM arguments are in use, which mutually excludes garbage collector and optimization settings.
    var isUsingCustomArguments: Bool {
        !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The effective Java executable path, preferring the local override over the stored game configuration.
    var effectiveJavaPath: String {
        if !javaPath.isEmpty {
            return javaPath
        }
        return currentGame?.javaPath ?? ""
    }

    /// A description of the Java runtime details for display in an info popover.
    var javaDetailsDescription: String {
        JavaDetailsFormatting.description(
            javaExecutablePath: effectiveJavaPath,
            versionOutput: javaVersionInfo,
        )
    }

    /// The Java version of the currently selected game.
    var currentJavaVersion: Int {
        currentGame?.javaVersion ?? 8
    }

    /// The garbage collectors available for the current Java version.
    var availableGarbageCollectors: [GarbageCollector] {
        GarbageCollector.allCases.filter { $0.isSupported(by: currentJavaVersion) }
    }

    /// The optimization presets available for the currently selected garbage collector.
    var availableOptimizationPresets: [OptimizationPreset] {
        if selectedGarbageCollector == .g1gc {
            return OptimizationPreset.allCases
        }
        return OptimizationPreset.allCases.filter { $0 != .maximum }
    }

    func setRepository(_ repository: GameRepository) {
        gameRepository = repository
    }

    func onAppearOrGameChanged() {
        loadCurrentSettings()
        loadJavaVersionInfo()
    }

    func onJavaPathChanged() {
        loadJavaVersionInfo()
    }

    func didSelectGarbageCollector() {
        guard !isUsingCustomArguments else { return }

        if !selectedGarbageCollector.isSupported(by: currentJavaVersion) {
            selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
        }

        if optimizationPreset == .maximum, selectedGarbageCollector != .g1gc {
            optimizationPreset = .balanced
            applyOptimizationPreset(.balanced)
        }

        autoSave()
    }

    func didSelectOptimizationPreset(_ newValue: OptimizationPreset) {
        guard !isUsingCustomArguments else { return }
        applyOptimizationPreset(newValue)
        autoSave()
    }

    func didChangeMemoryRange() {
        autoSave()
    }

    func didChangeCustomJvmArguments() {
        autoSave()
    }

    func didChangeEnvironmentVariables() {
        autoSave()
    }

    func resetToDefaults() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        memoryRange = Double(DIContainer.shared.ui.gameSettingsManager.globalXms) ... Double(DIContainer.shared.ui.gameSettingsManager.globalXmx)
        selectedGarbageCollector = availableGarbageCollectors.first ?? .g1gc
        optimizationPreset = .balanced
        applyOptimizationPreset(.balanced)
        customJvmArguments = ""
        environmentVariables = ""
        resetJavaPathSafely()
        autoSave()
    }

    func resetJavaPathSafely() {
        guard let game = currentGame else { return }

        Task {
            let defaultPath = await DIContainer.shared.system.javaManager.findDefaultJavaPath(for: game.gameVersion)
            await MainActor.run {
                self.javaPath = defaultPath
                self.autoSave()
            }
        }
    }

    func resetGameXms() {
        guard let game = currentGame else { return }
        var updatedGame = game
        updatedGame.xms = 0
        updatedGame.xmx = 0
        memoryRange = Double(AppConstants.MemoryDefaults.xms) ... Double(AppConstants.MemoryDefaults.xmx)
        Task {
            try? await gameRepository?.updateGame(updatedGame)
        }
    }

    func handleJavaPathSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
                    i18nKey: "error.filesystem.file_not_found",
                    level: .notification,
                    source: .settings,
                ))
                return
            }

            if DIContainer.shared.system.javaManager.canJavaRun(at: url.path) {
                javaPath = url.path
                autoSave()
                AppLog.game.info("Java path set to: \(url.path)")
            } else {
                DIContainer.shared.core.errorHandler.handle(GlobalError.validation(
                    i18nKey: "error.validation.invalid_java_executable",
                    level: .popup,
                    source: .settings,
                ))
            }

        case .failure:
            DIContainer.shared.core.errorHandler.handle(GlobalError.fileSystem(
                i18nKey: "error.filesystem.java_path_selection_failed",
                level: .notification,
                source: .settings,
            ))
        }
    }
}
