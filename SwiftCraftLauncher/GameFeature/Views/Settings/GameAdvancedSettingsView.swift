//
//  GameAdvancedSettingsView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Per-game advanced settings for Java path, garbage collector, memory, and JVM arguments.
import SwiftUI

struct GameAdvancedSettingsView: View {
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel = GameAdvancedSettingsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            GameAdvancedSettingsGarbageCollectorSection(viewModel: viewModel)
                .id("settings.game.java.garbage_collector")
            GameAdvancedSettingsJavaPathSection(viewModel: viewModel)
                .id("settings.game.java.path")
            GameAdvancedSettingsPerformanceOptimizationSection(viewModel: viewModel)
                .id("settings.game.java.performance_optimization")
            GameAdvancedSettingsMemorySection(viewModel: viewModel)
                .id("settings.game.java.memory")
            Section {
                GameAdvancedSettingsCustomParametersSection(viewModel: viewModel)
                    .id("settings.game.java.custom_parameters")
                GameAdvancedSettingsEnvironmentVariablesSection(viewModel: viewModel)
                    .id("settings.game.java.environment_variables")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.setRepository(gameRepository)
            viewModel.onAppearOrGameChanged()
        }
        .onChange(of: container.core.selectedGameManager.selectedGameId) { _, _ in
            viewModel.setRepository(gameRepository)
            viewModel.onAppearOrGameChanged()
        }
        .onChange(of: viewModel.javaPath) { _, _ in
            viewModel.onJavaPathChanged()
        }
        .errorHandler(container.core.errorHandler)
    }
}
