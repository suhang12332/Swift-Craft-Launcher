//
//  GameAdvancedSettingsView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import UniformTypeIdentifiers

struct GameAdvancedSettingsView: View {
    @EnvironmentObject private var gameRepository: GameRepository
    @StateObject private var selectedGameManager: SelectedGameManager
    @StateObject private var viewModel = GameAdvancedSettingsViewModel()

    @State private var showJavaPathPicker = false

    init(selectedGameManager: SelectedGameManager = AppServices.selectedGameManager) {
        _selectedGameManager = StateObject(wrappedValue: selectedGameManager)
    }

    var body: some View {
        Form {
            LabeledContent("settings.game.java.path".localized()) {
                HStack(alignment: .top) {
                    DirectorySettingRow(
                        title: "settings.game.java.path".localized(),
                        path: viewModel.javaPath.isEmpty ? (viewModel.currentGame?.javaPath ?? "") : viewModel.javaPath,
                        description: "settings.game.java.path.description".localized(),
                        onChoose: { showJavaPathPicker = true },
                        onReset: {
                            viewModel.resetJavaPathSafely()
                        }
                    ).fixedSize()
                        .fileImporter(
                            isPresented: $showJavaPathPicker,
                            allowedContentTypes: [.item],
                            allowsMultipleSelection: false
                        ) { result in
                            viewModel.handleJavaPathSelection(result)
                        }
                    InfoIconWithPopover(
                        text: viewModel.javaDetailsDescription
                    )
                }
            }.labeledContentStyle(.custom)

            Group {
                LabeledContent("settings.game.java.garbage_collector".localized()) {
                    Picker("", selection: $viewModel.selectedGarbageCollector) {
                        ForEach(viewModel.availableGarbageCollectors, id: \.self) { gc in
                            Text(gc.displayName).tag(gc)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(viewModel.isUsingCustomArguments)  // 使用自定义参数时禁用
                    .onChange(of: viewModel.selectedGarbageCollector) { _, _ in
                        viewModel.didSelectGarbageCollector()
                    }
                }
                .labeledContentStyle(.custom)
                .opacity(viewModel.isUsingCustomArguments ? 0.5 : 1.0)  // 禁用时降低透明度
                CommonDescriptionText(text: viewModel.selectedGarbageCollector.description)
            }

            Group {
                LabeledContent("settings.game.java.performance_optimization".localized()) {
                    Picker("", selection: $viewModel.optimizationPreset) {
                        // 最大优化仅在 G1GC 时可用
                        ForEach(viewModel.availableOptimizationPresets, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(viewModel.isUsingCustomArguments)  // 使用自定义参数时禁用
                    .onChange(of: viewModel.optimizationPreset) { _, newValue in
                        viewModel.didSelectOptimizationPreset(newValue)
                    }
                }
                .labeledContentStyle(.custom)
                .opacity(viewModel.isUsingCustomArguments ? 0.5 : 1.0)  // 禁用时降低透明度
                CommonDescriptionText(text: viewModel.optimizationPreset.description)
            }

            LabeledContent("settings.game.java.memory".localized()) {
                HStack {
                    MiniRangeSlider(
                        range: $viewModel.memoryRange,
                        bounds: 512...Double(viewModel.gameSettingsManager.maximumMemoryAllocation)
                    )
                    .frame(width: 200)
                    .controlSize(.mini)
                    .onChange(of: viewModel.memoryRange) { _, _ in viewModel.didChangeMemoryRange() }
                    Text("\(Int(viewModel.memoryRange.lowerBound)) MB-\(Int(viewModel.memoryRange.upperBound)) MB")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
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
                        .lineLimit(2...4)
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
                        .lineLimit(2...4)
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
        .onChange(of: selectedGameManager.selectedGameId) { _, _ in
            viewModel.setRepository(gameRepository)
            viewModel.onAppearOrGameChanged()
        }
        .onChange(of: viewModel.javaPath) { _, _ in
            viewModel.onJavaPathChanged()
        }
        .errorHandler()
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(viewModel.error != nil && viewModel.error?.level == .popup)
        ) {
            Button("common.close".localized()) {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}
