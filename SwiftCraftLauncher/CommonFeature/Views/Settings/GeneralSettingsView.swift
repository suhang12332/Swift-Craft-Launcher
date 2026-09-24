//
//  GeneralSettingsView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view for configuring general launcher settings.
public struct GeneralSettingsView: View {
    let page: SettingsPage
    @Environment(DIContainer.self)
    private var container
    @State private var viewModel: GeneralSettingsViewModel
    @Environment(GameRepository.self)
    private var gameRepository

    @MainActor
    init(page: SettingsPage) {
        self.page = page
        _viewModel = State(wrappedValue: GeneralSettingsViewModel())
    }

    public var body: some View {
        Form {
            switch page {
            case .general:
                Section {
                    GeneralSettingsLanguageRow(languageManager: container.ui.languageManager)
                        .id("settings.language.picker")
                    GeneralSettingsCommonSheetHeightLimitRow()
                        .environment(container.ui.generalSettingsManager)
                        .id("settings.common_sheet_height_limit.label")
                }
            case .appearance:
                Section {
                    GeneralSettingsThemeRow()
                        .environment(container.ui.themeManager)
                        .id("settings.theme.picker")
                    GeneralSettingsInterfaceLayoutRow()
                        .environment(container.ui.generalSettingsManager)
                        .id("settings.interface_style.label")
                }
            case .files:
                Section {
                    GeneralSettingsWorkingDirectoryRow(
                        viewModel: viewModel,
                        gameRepository: gameRepository,
                    )
                    .environment(container.ui.generalSettingsManager)
                    .id("settings.launcher_working_directory")
                }
            case .network:
                Section {
                    GeneralSettingsSystemProxyRow()
                        .id("settings.system_proxy.label")
                    GameSettingsAPISourceRow()
                        .id("settings.default_api_source.label")
                }
            default:
                EmptyView()
            }
        }
        .formStyle(.grouped)
        .errorHandler(container.core.errorHandler)
        .onAppear {
            viewModel.configure(gameRepository: gameRepository)
        }
    }
}
