//
//  GameSettingsSections.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// A row for choosing the default mod/API source.
struct GameSettingsAPISourceRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.default_api_source.label".localized()) {
            Picker("", selection: $gameSettingsManager.defaultAPISource) {
                ForEach(DataSource.allCases, id: \.self) { source in
                    Text(source.localizedName).tag(source)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// A row for choosing the default mod pack export format.
struct GameSettingsModPackExportFormatRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.modpack.export.format.label".localized()) {
            Picker("", selection: $gameSettingsManager.defaultModPackExportFormat) {
                ForEach(ModPackExportFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// A row toggling whether snapshot versions appear in game version selection.
struct GameSettingsIncludeSnapshotsRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
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
    }
}

/// A row toggling AI crash analysis.
struct GameSettingsAICrashAnalysisRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.ai_crash_analysis".localized()) {
            HStack {
                Toggle(
                    "",
                    isOn: $gameSettingsManager.enableAICrashAnalysis,
                ).labelsHidden()
                Text("settings.ai_crash_analysis.description".localized())
            }
        }
    }
}

/// A row toggling the memory pressure warning.
struct GameSettingsMemoryPressureWarningRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.memory_pressure_warning.label".localized()) {
            HStack {
                Toggle(
                    "",
                    isOn: $gameSettingsManager.enableMemoryPressureWarning,
                ).labelsHidden()
                Text("settings.memory_pressure_warning.description".localized())
            }
        }
    }
}

/// A row toggling whether new games sync their language with the launcher.
struct GameSettingsSyncLanguageRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
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
    }
}

/// A row with a slider for the maximum concurrent download count.
struct GameSettingsConcurrentDownloadsRow: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager
    @Binding var draft: Double

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.concurrent_downloads.label".localized()) {
            HStack {
                Slider(
                    value: $draft,
                    in: 1 ... 64,
                ) { isEditing in
                    if !isEditing {
                        gameSettingsManager.concurrentDownloads = Int(draft.rounded())
                    }
                }
                .controlSize(.mini)

                Text("\(Int(draft.rounded()))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
            .frame(width: 200)
            .gridColumnAlignment(.leading)
            .labelsHidden()
        }
        .onAppear { draft = Double(gameSettingsManager.concurrentDownloads) }
    }
}

/// A section with a range slider for the default memory allocation.
struct GameSettingsMemoryAllocationSection: View {
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager
    @Binding var range: ClosedRange<Double>

    var body: some View {
        @Bindable var gameSettingsManager = gameSettingsManager
        LabeledContent("settings.default_memory_allocation.label".localized()) {
            HStack {
                MiniRangeSlider(
                    range: $range,
                    bounds:
                    Double(AppConstants.MemoryDefaults.xms) ... Double(gameSettingsManager.maximumMemoryAllocation),
                )
                .frame(width: 200)
                .controlSize(.mini)
                .onChange(of: range) { _, newValue in
                    gameSettingsManager.globalXms = Int(newValue.lowerBound)
                    gameSettingsManager.globalXmx = Int(newValue.upperBound)
                }
                .onAppear {
                    range =
                        Double(
                            gameSettingsManager.globalXms,
                        ) ... Double(gameSettingsManager.globalXmx)
                }
                Button("common.reset".localized()) {
                    gameSettingsManager.globalXms = AppConstants.MemoryDefaults.xms
                    gameSettingsManager.globalXmx = AppConstants.MemoryDefaults.xmx
                    range = Double(AppConstants.MemoryDefaults.xms) ... Double(AppConstants.MemoryDefaults.xmx)
                }
                .padding(.leading, 8)
            }
        }
        Text(
            "\(Int(range.lowerBound)) MB-\(Int(range.upperBound)) MB",
        )
        .font(.subheadline.monospacedDigit())
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.bottom, 4)
        CommonDescriptionText(
            text: "settings.default_memory_allocation.description".localized(),
        )
    }
}

/// A row for selecting and reinstalling the default Java runtime.
struct GameSettingsJavaRuntimeRow: View {
    @Environment(DIContainer.self)
    private var container
    @Bindable var viewModel: GameSettingsJavaRuntimeViewModel

    var body: some View {
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
    }
}
