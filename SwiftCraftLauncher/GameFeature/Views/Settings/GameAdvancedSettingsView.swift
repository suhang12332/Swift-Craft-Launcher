//
//  GameAdvancedSettingsView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Per-game advanced settings for Java path, garbage collector, memory, and JVM arguments.
import SwiftUI
import UniformTypeIdentifiers

struct GameAdvancedSettingsView: View {
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel = GameAdvancedSettingsViewModel()

    @State private var showJavaPathPicker = false

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Group {
                LabeledContent("settings.game.java.path".localized()) {
                    HStack(alignment: .top) {
                        DirectorySettingRow(
                            title: "settings.game.java.path".localized(),
                            path: viewModel.javaPath.isEmpty ? (viewModel.currentGame?.javaPath ?? "") : viewModel.javaPath,
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
                    }
                }.labeledContentStyle(.custom)
                InfoIconWithPopover(
                    text: viewModel.javaDetailsDescription,
                )
            }

            Group {
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

            Group {
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
                .labeledContentStyle(.custom)
                .opacity(viewModel.isUsingCustomArguments ? 0.5 : 1.0)
                CommonDescriptionText(text: viewModel.optimizationPreset.description)
            }

            LabeledContent("settings.game.java.memory".localized()) {
                HStack {
                    MiniRangeSlider(
                        range: $viewModel.memoryRange,
                        bounds: Double(AppConstants.MemoryDefaults.xms) ... Double(container.ui.gameSettingsManager.maximumMemoryAllocation),
                    )
                    .frame(width: 200)
                    .controlSize(.mini)
                    .onChange(of: viewModel.memoryRange) { _, _ in viewModel.didChangeMemoryRange() }
                    Text("\(Int(viewModel.memoryRange.lowerBound)) MB-\(Int(viewModel.memoryRange.upperBound)) MB")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("common.reset".localized()) {
                        viewModel.resetGameXms()
                    }
                    .padding(.leading, 8)
                }
            }
            .labeledContentStyle(.custom)
            .padding(.vertical, 10)

            Group {
                LabeledContent("settings.game.java.custom_parameters".localized()) {
                    TextField("", text: $viewModel.customJvmArguments)
                        .focusable(false)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2 ... 4)
                        .frame(width: 300)
                        .onChange(of: viewModel.customJvmArguments) { _, _ in viewModel.didChangeCustomJvmArguments() }
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(text: "settings.game.java.custom_parameters.note".localized())
            }

            Group {
                LabeledContent("settings.game.java.environment_variables".localized()) {
                    TextField("", text: $viewModel.environmentVariables, axis: .vertical)
                        .focusable(false)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2 ... 4)
                        .frame(width: 300)
                        .onChange(of: viewModel.environmentVariables) { _, _ in viewModel.didChangeEnvironmentVariables() }
                }
                .labeledContentStyle(.custom)
                CommonDescriptionText(text: "example: JAVA_OPTS=-Dfile.encoding=UTF-8".localized())
            }
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
