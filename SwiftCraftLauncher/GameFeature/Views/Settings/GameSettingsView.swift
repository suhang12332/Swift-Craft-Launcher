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
                        .id("settings.modpack.export.format.label")
                    GameSettingsConcurrentDownloadsRow(draft: $concurrentDownloadsDraft)
                        .id("settings.concurrent_downloads.label")
                    GameSettingsIncludeSnapshotsRow()
                        .id("settings.game_versions.label")
                    GameSettingsSyncLanguageRow()
                        .id("settings.game.language.label")
                }
            } else {
                Section {
                    GameSettingsMemoryPressureWarningRow()
                        .id("settings.memory_pressure_warning.label")
                    GameSettingsMemoryAllocationSection(range: $globalMemoryRange)
                        .id("settings.default_memory_allocation.label")
                }
                Section {
                    GameSettingsJavaRuntimeRow(viewModel: viewModel)
                        .id("settings.game.java.runtimes.section")
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
