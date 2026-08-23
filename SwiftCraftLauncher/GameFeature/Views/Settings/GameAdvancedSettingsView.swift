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
            GameAdvancedSettingsJavaPathSection(viewModel: viewModel)
            GameAdvancedSettingsPerformanceOptimizationSection(viewModel: viewModel)
            GameAdvancedSettingsMemorySection(viewModel: viewModel)
            spacerView()
            GameAdvancedSettingsCustomParametersSection(viewModel: viewModel)
            GameAdvancedSettingsEnvironmentVariablesSection(viewModel: viewModel)
        }
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
