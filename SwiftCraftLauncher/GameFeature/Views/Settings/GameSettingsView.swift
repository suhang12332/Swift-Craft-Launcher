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

    @State private var concurrentDownloadsDraft: Double = 64

    public init() {
        _viewModel = State(initialValue: GameSettingsJavaRuntimeViewModel())
    }

    public var body: some View {
        Form {
            Section {
                GameSettingsAPISourceRow()
                GameSettingsModPackExportFormatRow()
                GameSettingsConcurrentDownloadsRow(draft: $concurrentDownloadsDraft)
                GameSettingsIncludeSnapshotsRow()
                GameSettingsAICrashAnalysisRow()
                GameSettingsMemoryPressureWarningRow()
                GameSettingsSyncLanguageRow()
            }
            Section {
                GameSettingsMemoryAllocationSection(range: $globalMemoryRange)
            }
            Section {
                GameSettingsJavaRuntimeRow(viewModel: viewModel)
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(gameSettingsManager)
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
