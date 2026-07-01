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
final class GameAdvancedSettingsViewModel: ObservableObject {
    let selectedGameManager: SelectedGameManager
    let gameSettingsManager: GameSettingsManager
    let javaManager: JavaManager
    var gameRepository: GameRepository?

    @Published var memoryRange: ClosedRange<Double>
    @Published var selectedGarbageCollector: GarbageCollector
    @Published var optimizationPreset: OptimizationPreset
    @Published var customJvmArguments: String
    @Published var environmentVariables: String
    @Published var javaPath: String
    @Published var javaVersionInfo: String
    @Published var error: GlobalError?
    @Published var isLoadingSettings: Bool

    var enableOptimizations: Bool = true
    var enableAikarFlags: Bool = false
    var enableMemoryOptimizations: Bool = true
    var enableThreadOptimizations: Bool = true
    var enableNetworkOptimizations: Bool = false

    var saveTask: Task<Void, Never>?

    init(
        selectedGameManager: SelectedGameManager = AppServices.selectedGameManager,
        gameSettingsManager: GameSettingsManager = AppServices.gameSettingsManager,
        javaManager: JavaManager = AppServices.javaManager,
    ) {
        self.selectedGameManager = selectedGameManager
        self.gameSettingsManager = gameSettingsManager
        self.javaManager = javaManager
        memoryRange = Double(gameSettingsManager.globalXms) ... Double(gameSettingsManager.globalXmx)
        selectedGarbageCollector = .g1gc
        optimizationPreset = .balanced
        customJvmArguments = ""
        environmentVariables = ""
        javaPath = ""
        javaVersionInfo = ""
        error = nil
        isLoadingSettings = false
    }

    var currentGame: GameVersionInfo? {
        guard let gameId = selectedGameManager.selectedGameId else { return nil }
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

        memoryRange = Double(gameSettingsManager.globalXms) ... Double(gameSettingsManager.globalXmx)
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
            let defaultPath = await javaManager.findDefaultJavaPath(for: game.gameVersion)
            await MainActor.run {
                self.javaPath = defaultPath
                self.autoSave()
            }
        }
    }

    func handleJavaPathSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                error = GlobalError.fileSystem(
                    i18nKey: "error.filesystem.file_not_found",
                    level: .notification,
                )
                return
            }

            if javaManager.canJavaRun(at: url.path) {
                javaPath = url.path
                autoSave()
                AppLog.game.info("Java path set to: \(url.path)")
            } else {
                error = GlobalError.validation(
                    i18nKey: "error.validation.invalid_java_executable",
                    level: .popup,
                )
            }

        case .failure:
            error = GlobalError.fileSystem(
                i18nKey: "error.filesystem.java_path_selection_failed",
                level: .notification,
            )
        }
    }
}
