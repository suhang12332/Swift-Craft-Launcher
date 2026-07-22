//
//  GameSettingsView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Global game settings view for API source, memory allocation, Java runtime, and cache management.
import Foundation
import SwiftUI

public struct GameSettingsView: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager
    @Environment(DIContainer.self)
    private var container

    @State private var viewModel: GameSettingsJavaRuntimeViewModel

    @State private var globalMemoryRange: ClosedRange<Double> = Double(AppConstants.MemoryDefaults.xms) ... Double(AppConstants.MemoryDefaults.xmx)

    public init() {
        _viewModel = State(initialValue: GameSettingsJavaRuntimeViewModel())
    }

    public var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        @Bindable var viewModel = viewModel
        VStack {
            Form {
                LabeledContent("settings.default_api_source.label".localized()) {
                    Picker("", selection: $gameSettingsManager.defaultAPISource) {
                        ForEach(DataSource.allCases, id: \.self) { source in
                            Text(source.localizedName).tag(source)
                        }
                    }

                    .labelsHidden()
                    .fixedSize()
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.modpack.export.format.label".localized()) {
                    Picker("", selection: $gameSettingsManager.defaultModPackExportFormat) {
                        ForEach(ModPackExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.game_versions.label".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettingsManager.includeSnapshotsForGameVersions,
                        )
                        .labelsHidden()
                        Text("settings.game_versions.include_snapshots.label".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.ai_crash_analysis".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettingsManager.enableAICrashAnalysis,
                        ).labelsHidden()
                        Text("settings.ai_crash_analysis.description".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.memory_pressure_warning.label".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettingsManager.enableMemoryPressureWarning,
                        ).labelsHidden()
                        Text("settings.memory_pressure_warning.description".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                LabeledContent("settings.game.language.label".localized()) {
                    HStack {
                        Toggle(
                            "",
                            isOn: $gameSettingsManager.syncLanguageForNewGames,
                        )
                        .labelsHidden()
                        Text("settings.game.language.sync_with_launcher".localized())
                    }
                }
                .labeledContentStyle(.custom)
                .padding(.bottom, 10)

                Group {
                    LabeledContent("settings.default_memory_allocation.label".localized()) {
                        HStack {
                            MiniRangeSlider(
                                range: $globalMemoryRange,
                                bounds:
                                Double(AppConstants.MemoryDefaults.xms) ... Double(gameSettingsManager.maximumMemoryAllocation),
                            )
                            .frame(width: 200)
                            .controlSize(.mini)
                            .onChange(of: globalMemoryRange) { _, newValue in
                                gameSettingsManager.globalXms = Int(newValue.lowerBound)
                                gameSettingsManager.globalXmx = Int(newValue.upperBound)
                            }
                            .onAppear {
                                globalMemoryRange =
                                    Double(
                                        gameSettingsManager.globalXms,
                                    ) ... Double(gameSettingsManager.globalXmx)
                            }
                            Text(
                                "\(Int(globalMemoryRange.lowerBound)) MB-\(Int(globalMemoryRange.upperBound)) MB",
                            )
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            Button("common.reset".localized()) {
                                gameSettingsManager.globalXms = AppConstants.MemoryDefaults.xms
                                gameSettingsManager.globalXmx = AppConstants.MemoryDefaults.xmx
                                globalMemoryRange = Double(AppConstants.MemoryDefaults.xms) ... Double(AppConstants.MemoryDefaults.xmx)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .labeledContentStyle(.custom)
                    CommonDescriptionText(
                        text: "settings.default_memory_allocation.description".localized(),
                    )
                }
                LabeledContent("settings.game.java.runtimes.section".localized()) {
                    HStack(spacing: 8) {
                        let components = viewModel.installedRuntimeComponents ?? []
                        Picker("", selection: $viewModel.selectedRuntimeComponent) {
                            if components.isEmpty {
                                Text("settings.game.java.runtime.none".localized())
                                    .tag("")
                            } else {
                                ForEach(components, id: \.self) { component in
                                    Text(component).tag(component)
                                }
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        .disabled((viewModel.installedRuntimeComponents ?? []).isEmpty)

                        Button("settings.game.java.runtime.reinstall".localized()) {
                            Task {
                                await container.system.javaDownloadManager.downloadJavaRuntime(
                                    version: viewModel.selectedRuntimeComponent,
                                )
                            }
                        }
                        .disabled(
                            viewModel.selectedRuntimeComponent.isEmpty
                                || container.system.javaDownloadManager.downloadState.isDownloading
                                || (viewModel.installedRuntimeComponents ?? []).isEmpty,
                        )

                        if !viewModel.selectedRuntimeComponent.isEmpty {
                            InfoIconWithPopover(text: viewModel.javaDetailsDescription)
                        }
                    }
                }
                .labeledContentStyle(.custom)
            }
            HStack {
                Spacer()
                Button {
                    Task {
                        await Task.detached(priority: .utility) {
                            await container.core.modCacheManager.clearSilently()
                        }.value
                    }
                } label: {
                    Text("settings.game.clear_cache.label".localized())
                }
                InfoIconWithPopover(text: "settings.game.clear_cache.help".localized())
            }
        }
        .onAppear {
            viewModel.refreshInstalledRuntimes(showScanningIndicator: true)
        }
        .onChange(of: container.system.javaDownloadManager.isWindowVisible) { _, isVisible in
            if !isVisible {
                viewModel.refreshInstalledRuntimes(showScanningIndicator: false)
            }
        }
        .onChange(of: viewModel.selectedRuntimeComponent) { _, newValue in
            viewModel.loadDetails(forRuntimeComponent: newValue)
        }
        .onChange(of: container.system.javaDownloadManager.downloadState.isDownloading) { _, isDownloading in
            if !isDownloading, !viewModel.selectedRuntimeComponent.isEmpty {
                viewModel.loadDetails(forRuntimeComponent: viewModel.selectedRuntimeComponent)
            }
        }
    }
}
