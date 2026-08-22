//
//  GameAdvancedSettingsSections.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A section for choosing the Java executable path for the current game.
struct GameAdvancedSettingsJavaPathSection: View {
    @Bindable var viewModel: GameAdvancedSettingsViewModel
    @State private var showJavaPathPicker = false

    var body: some View {
        LabeledContent("settings.game.java.path".localized()) {
            HStack(alignment: .top, spacing: 8) {
                DirectorySettingRow(
                    title: "settings.game.java.path".localized(),
                    path: viewModel.effectiveJavaPath,
                    description: "settings.game.java.path.description".localized(),
                    onChoose: { showJavaPathPicker = true },
                    onReset: {
                        viewModel.resetJavaPathSafely()
                    },
                ).fixedSize()
                    .fileImporter(
                        isPresented: $showJavaPathPicker,
                        allowedContentTypes: [.item],
                        allowsMultipleSelection: false,
                    ) { result in
                        viewModel.handleJavaPathSelection(result)
                    }
                InfoIconWithPopover(
                    text: viewModel.javaDetailsDescription,
                )
            }
        }
    }
}

/// A row for choosing the garbage collector for the current game.
struct GameAdvancedSettingsGarbageCollectorSection: View {
    @Bindable var viewModel: GameAdvancedSettingsViewModel

    var body: some View {
        LabeledContent("settings.game.java.garbage_collector".localized()) {
            Picker("", selection: $viewModel.selectedGarbageCollector) {
                ForEach(viewModel.availableGarbageCollectors, id: \.self) { gc in
                    Text(gc.displayName).tag(gc)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(viewModel.isUsingCustomArguments)
            .onChange(of: viewModel.selectedGarbageCollector) { _, _ in
                viewModel.didSelectGarbageCollector()
            }
        }
        .labeledContentStyle(.custom)
        .opacity(viewModel.isUsingCustomArguments ? 0.5 : 1.0)
        CommonDescriptionText(text: viewModel.selectedGarbageCollector.description)
    }
}

/// A row for choosing the performance optimization preset for the current game.
struct GameAdvancedSettingsPerformanceOptimizationSection: View {
    @Bindable var viewModel: GameAdvancedSettingsViewModel

    var body: some View {
        LabeledContent("settings.game.java.performance_optimization".localized()) {
            Picker("", selection: $viewModel.optimizationPreset) {
                ForEach(viewModel.availableOptimizationPresets, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(viewModel.isUsingCustomArguments)
            .onChange(of: viewModel.optimizationPreset) { _, newValue in
                viewModel.didSelectOptimizationPreset(newValue)
            }
        }
        .opacity(viewModel.isUsingCustomArguments ? 0.5 : 1.0)
        CommonDescriptionText(text: viewModel.optimizationPreset.description)
    }
}

/// A section with a range slider for the current game's memory allocation.
struct GameAdvancedSettingsMemorySection: View {
    @Environment(DIContainer.self)
    private var container
    @Bindable var viewModel: GameAdvancedSettingsViewModel

    var body: some View {
        LabeledContent("settings.game.java.memory".localized()) {
            HStack {
                MiniRangeSlider(
                    range: $viewModel.memoryRange,
                    bounds:
                    Double(AppConstants.MemoryDefaults.xms) ... Double(container.ui.gameSettingsManager.maximumMemoryAllocation),
                )
                .frame(width: 200)
                .controlSize(.mini)
                .onChange(of: viewModel.memoryRange) { _, _ in viewModel.didChangeMemoryRange() }
                Button("common.reset".localized()) {
                    viewModel.resetGameXms()
                }
                .padding(.leading, 8)
            }
        }
        Text("\(Int(viewModel.memoryRange.lowerBound)) MB-\(Int(viewModel.memoryRange.upperBound)) MB")
            .font(.subheadline.monospacedDigit())
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.bottom, 4)
    }
}

/// A row for entering custom JVM arguments for the current game.
struct GameAdvancedSettingsCustomParametersSection: View {
    @Bindable var viewModel: GameAdvancedSettingsViewModel

    var body: some View {
        LabeledContent("settings.game.java.custom_parameters".localized()) {
            TextField("", text: $viewModel.customJvmArguments)
                .focusable(false)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .lineLimit(2 ... 4)
                .frame(width: 300)
                .onChange(of: viewModel.customJvmArguments) { _, _ in viewModel.didChangeCustomJvmArguments() }
        }
        CommonDescriptionText(text: "settings.game.java.custom_parameters.note".localized())
    }
}

/// A row for entering environment variables for the current game.
struct GameAdvancedSettingsEnvironmentVariablesSection: View {
    @Bindable var viewModel: GameAdvancedSettingsViewModel

    var body: some View {
        LabeledContent("settings.game.java.environment_variables".localized()) {
            TextField("", text: $viewModel.environmentVariables, axis: .vertical)
                .focusable(false)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .lineLimit(2 ... 4)
                .frame(width: 300)
                .onChange(of: viewModel.environmentVariables) { _, _ in viewModel.didChangeEnvironmentVariables() }
        }
        CommonDescriptionText(text: "settings.game.java.environment_variables.description".localized())
    }
}
