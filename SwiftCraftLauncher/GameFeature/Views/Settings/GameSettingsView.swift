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
    let page: SettingsPage
    @Environment(GameSettingsManager.self)
    private var gameSettingsManager
    @Environment(DIContainer.self)
    private var container

    @State private var viewModel: GameSettingsJavaRuntimeViewModel

    @State private var globalMemoryRange: ClosedRange<Double> = Double(AppConstants.MemoryDefaults.xms) ... Double(AppConstants.MemoryDefaults.xmx)

    @State private var concurrentDownloadsDraft: Double = 64

    init(page: SettingsPage) {
        self.page = page
        _viewModel = State(initialValue: GameSettingsJavaRuntimeViewModel())
    }

    public var body: some View {
        Form {
            if page == .downloads {
                Section {
                    GameSettingsModPackExportFormatRow()
                    GameSettingsConcurrentDownloadsRow(draft: $concurrentDownloadsDraft)
                    GameSettingsIncludeSnapshotsRow()
                    GameSettingsSyncLanguageRow()
                }
            } else {
                Section {
                    GameSettingsMemoryPressureWarningRow()
                    GameSettingsMemoryAllocationSection(range: $globalMemoryRange)
                }
                Section {
                    GameSettingsJavaRuntimeRow(viewModel: viewModel)
                }
            }
        }
        .formStyle(.grouped)
        .environment(gameSettingsManager)
        .onAppear {
            if page == .java {
                viewModel.refreshInstalledRuntimes(showScanningIndicator: true)
            }
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
